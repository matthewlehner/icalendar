defmodule ICalendar.DateHelper do
  @moduledoc """
  Utility functions for date/time manipulation that replace functionality
  previously provided by Timex.

  Provides calendar arithmetic (shifting dates by days, months, years) and
  Windows-to-IANA timezone name conversion.
  """

  @type datetime :: DateTime.t() | NaiveDateTime.t()
  @type shift_opts :: [days: integer(), months: integer(), years: integer()]

  @doc """
  Shifts a `DateTime` or `NaiveDateTime` by the given options.

  Supports `:days`, `:months`, and `:years` options. Preserves wall clock time
  when shifting across DST boundaries.

  For timezone-aware `DateTime` values, the shift is performed on the wall clock
  time (naive) and then re-localized. This means a 10:00 AM event shifted by 1
  day will still be at 10:00 AM, even across DST transitions.

  When a shift lands on an ambiguous time (DST fall-back), the post-transition
  time is chosen. When a shift lands in a gap (DST spring-forward), the
  post-gap time is chosen.

  ## Examples

      iex> dt = ~U[2020-01-15 10:00:00Z]
      iex> ICalendar.DateHelper.shift(dt, days: 1)
      ~U[2020-01-16 10:00:00Z]

      iex> dt = ~U[2020-01-31 10:00:00Z]
      iex> ICalendar.DateHelper.shift(dt, months: 1)
      ~U[2020-02-29 10:00:00Z]

  """
  @spec shift(datetime(), shift_opts()) :: datetime()
  def shift(datetime, opts) do
    days = Keyword.get(opts, :days, 0)
    months = Keyword.get(opts, :months, 0)
    years = Keyword.get(opts, :years, 0)

    datetime
    |> shift_years(years)
    |> shift_months(months)
    |> shift_days(days)
  end

  defp shift_years(datetime, 0), do: datetime

  defp shift_years(%DateTime{} = dt, years) do
    naive = DateTime.to_naive(dt)
    shifted = shift_years(naive, years)
    from_naive_with_timezone(shifted, dt.time_zone)
  end

  defp shift_years(%NaiveDateTime{} = dt, years) do
    new_year = dt.year + years
    day = clamp_day(new_year, dt.month, dt.day)
    %{dt | year: new_year, day: day}
  end

  defp shift_months(datetime, 0), do: datetime

  defp shift_months(%DateTime{} = dt, months) do
    naive = DateTime.to_naive(dt)
    shifted = shift_months(naive, months)
    from_naive_with_timezone(shifted, dt.time_zone)
  end

  defp shift_months(%NaiveDateTime{} = dt, months) do
    total_months = dt.year * 12 + (dt.month - 1) + months
    new_year = div(total_months, 12)
    new_month = rem(total_months, 12) + 1

    # Handle negative remainders
    {new_year, new_month} =
      if new_month <= 0 do
        {new_year - 1, new_month + 12}
      else
        {new_year, new_month}
      end

    day = clamp_day(new_year, new_month, dt.day)
    %{dt | year: new_year, month: new_month, day: day}
  end

  defp shift_days(datetime, 0), do: datetime

  defp shift_days(%DateTime{} = dt, days) do
    naive = DateTime.to_naive(dt)
    shifted = NaiveDateTime.add(naive, days * 86_400, :second)
    from_naive_with_timezone(shifted, dt.time_zone)
  end

  defp shift_days(%NaiveDateTime{} = dt, days) do
    NaiveDateTime.add(dt, days * 86_400, :second)
  end

  defp clamp_day(year, month, day) do
    max_day = Calendar.ISO.days_in_month(year, month)
    min(day, max_day)
  end

  defp from_naive_with_timezone(naive, "Etc/UTC") do
    DateTime.from_naive!(naive, "Etc/UTC")
  end

  defp from_naive_with_timezone(naive, time_zone) do
    case DateTime.from_naive(naive, time_zone) do
      {:ok, dt} ->
        dt

      {:ambiguous, _first, second} ->
        # DST fall-back: pick the post-transition (standard time) interpretation
        second

      {:gap, _just_before, just_after} ->
        # DST spring-forward: pick the post-gap time
        just_after

      {:error, reason} ->
        raise ArgumentError,
              "cannot shift datetime to #{time_zone}: #{inspect(reason)}"
    end
  end

  @doc """
  Converts a Windows timezone name to an IANA/Olson timezone name.

  Returns the IANA timezone name as a string, or `nil` if the Windows
  timezone name is not recognized.

  The mapping is sourced from Unicode CLDR's `windowsZones.xml`, using the
  `territory="001"` (default) entries.

  ## Examples

      iex> ICalendar.DateHelper.windows_to_olson("Eastern Standard Time")
      "America/New_York"

      iex> ICalendar.DateHelper.windows_to_olson("Greenwich Standard Time")
      "Atlantic/Reykjavik"

      iex> ICalendar.DateHelper.windows_to_olson("Unknown Zone")
      nil

  """
  # Source: Unicode CLDR windowsZones.xml (territory="001" entries)
  # https://github.com/unicode-org/cldr/blob/main/common/supplemental/windowsZones.xml
  # Version: 2021a / otherVersion 7e11800
  @windows_to_olson %{
    "Dateline Standard Time" => "Etc/GMT+12",
    "UTC-11" => "Etc/GMT+11",
    "Aleutian Standard Time" => "America/Adak",
    "Hawaiian Standard Time" => "Pacific/Honolulu",
    "Marquesas Standard Time" => "Pacific/Marquesas",
    "Alaskan Standard Time" => "America/Anchorage",
    "UTC-09" => "Etc/GMT+9",
    "Pacific Standard Time (Mexico)" => "America/Tijuana",
    "UTC-08" => "Etc/GMT+8",
    "Pacific Standard Time" => "America/Los_Angeles",
    "US Mountain Standard Time" => "America/Phoenix",
    "Mountain Standard Time (Mexico)" => "America/Mazatlan",
    "Mountain Standard Time" => "America/Denver",
    "Yukon Standard Time" => "America/Whitehorse",
    "Central America Standard Time" => "America/Guatemala",
    "Central Standard Time" => "America/Chicago",
    "Easter Island Standard Time" => "Pacific/Easter",
    "Central Standard Time (Mexico)" => "America/Mexico_City",
    "Canada Central Standard Time" => "America/Regina",
    "SA Pacific Standard Time" => "America/Bogota",
    "Eastern Standard Time (Mexico)" => "America/Cancun",
    "Eastern Standard Time" => "America/New_York",
    "Haiti Standard Time" => "America/Port-au-Prince",
    "Cuba Standard Time" => "America/Havana",
    "US Eastern Standard Time" => "America/Indianapolis",
    "Turks And Caicos Standard Time" => "America/Grand_Turk",
    "Paraguay Standard Time" => "America/Asuncion",
    "Atlantic Standard Time" => "America/Halifax",
    "Venezuela Standard Time" => "America/Caracas",
    "Central Brazilian Standard Time" => "America/Cuiaba",
    "SA Western Standard Time" => "America/La_Paz",
    "Pacific SA Standard Time" => "America/Santiago",
    "Newfoundland Standard Time" => "America/St_Johns",
    "Tocantins Standard Time" => "America/Araguaina",
    "E. South America Standard Time" => "America/Sao_Paulo",
    "SA Eastern Standard Time" => "America/Cayenne",
    "Argentina Standard Time" => "America/Buenos_Aires",
    "Greenland Standard Time" => "America/Godthab",
    "Montevideo Standard Time" => "America/Montevideo",
    "Magallanes Standard Time" => "America/Punta_Arenas",
    "Saint Pierre Standard Time" => "America/Miquelon",
    "Bahia Standard Time" => "America/Bahia",
    "UTC-02" => "Etc/GMT+2",
    "Azores Standard Time" => "Atlantic/Azores",
    "Cape Verde Standard Time" => "Atlantic/Cape_Verde",
    "UTC" => "Etc/UTC",
    "GMT Standard Time" => "Europe/London",
    "Greenwich Standard Time" => "Atlantic/Reykjavik",
    "Sao Tome Standard Time" => "Africa/Sao_Tome",
    "Morocco Standard Time" => "Africa/Casablanca",
    "W. Europe Standard Time" => "Europe/Berlin",
    "Central Europe Standard Time" => "Europe/Budapest",
    "Romance Standard Time" => "Europe/Paris",
    "Central European Standard Time" => "Europe/Warsaw",
    "W. Central Africa Standard Time" => "Africa/Lagos",
    "Jordan Standard Time" => "Asia/Amman",
    "GTB Standard Time" => "Europe/Bucharest",
    "Middle East Standard Time" => "Asia/Beirut",
    "Egypt Standard Time" => "Africa/Cairo",
    "E. Europe Standard Time" => "Europe/Chisinau",
    "Syria Standard Time" => "Asia/Damascus",
    "West Bank Standard Time" => "Asia/Hebron",
    "South Africa Standard Time" => "Africa/Johannesburg",
    "FLE Standard Time" => "Europe/Kiev",
    "Israel Standard Time" => "Asia/Jerusalem",
    "South Sudan Standard Time" => "Africa/Juba",
    "Kaliningrad Standard Time" => "Europe/Kaliningrad",
    "Sudan Standard Time" => "Africa/Khartoum",
    "Libya Standard Time" => "Africa/Tripoli",
    "Namibia Standard Time" => "Africa/Windhoek",
    "Arabic Standard Time" => "Asia/Baghdad",
    "Turkey Standard Time" => "Europe/Istanbul",
    "Arab Standard Time" => "Asia/Riyadh",
    "Belarus Standard Time" => "Europe/Minsk",
    "Russian Standard Time" => "Europe/Moscow",
    "E. Africa Standard Time" => "Africa/Nairobi",
    "Iran Standard Time" => "Asia/Tehran",
    "Arabian Standard Time" => "Asia/Dubai",
    "Astrakhan Standard Time" => "Europe/Astrakhan",
    "Azerbaijan Standard Time" => "Asia/Baku",
    "Russia Time Zone 3" => "Europe/Samara",
    "Mauritius Standard Time" => "Indian/Mauritius",
    "Saratov Standard Time" => "Europe/Saratov",
    "Georgian Standard Time" => "Asia/Tbilisi",
    "Volgograd Standard Time" => "Europe/Volgograd",
    "Caucasus Standard Time" => "Asia/Yerevan",
    "Afghanistan Standard Time" => "Asia/Kabul",
    "West Asia Standard Time" => "Asia/Tashkent",
    "Ekaterinburg Standard Time" => "Asia/Yekaterinburg",
    "Pakistan Standard Time" => "Asia/Karachi",
    "Qyzylorda Standard Time" => "Asia/Qyzylorda",
    "India Standard Time" => "Asia/Calcutta",
    "Sri Lanka Standard Time" => "Asia/Colombo",
    "Nepal Standard Time" => "Asia/Katmandu",
    "Central Asia Standard Time" => "Asia/Bishkek",
    "Bangladesh Standard Time" => "Asia/Dhaka",
    "Omsk Standard Time" => "Asia/Omsk",
    "Myanmar Standard Time" => "Asia/Rangoon",
    "SE Asia Standard Time" => "Asia/Bangkok",
    "Altai Standard Time" => "Asia/Barnaul",
    "W. Mongolia Standard Time" => "Asia/Hovd",
    "North Asia Standard Time" => "Asia/Krasnoyarsk",
    "N. Central Asia Standard Time" => "Asia/Novosibirsk",
    "Tomsk Standard Time" => "Asia/Tomsk",
    "China Standard Time" => "Asia/Shanghai",
    "North Asia East Standard Time" => "Asia/Irkutsk",
    "Singapore Standard Time" => "Asia/Singapore",
    "W. Australia Standard Time" => "Australia/Perth",
    "Taipei Standard Time" => "Asia/Taipei",
    "Ulaanbaatar Standard Time" => "Asia/Ulaanbaatar",
    "Aus Central W. Standard Time" => "Australia/Eucla",
    "Transbaikal Standard Time" => "Asia/Chita",
    "Tokyo Standard Time" => "Asia/Tokyo",
    "North Korea Standard Time" => "Asia/Pyongyang",
    "Korea Standard Time" => "Asia/Seoul",
    "Yakutsk Standard Time" => "Asia/Yakutsk",
    "Cen. Australia Standard Time" => "Australia/Adelaide",
    "AUS Central Standard Time" => "Australia/Darwin",
    "E. Australia Standard Time" => "Australia/Brisbane",
    "AUS Eastern Standard Time" => "Australia/Sydney",
    "West Pacific Standard Time" => "Pacific/Port_Moresby",
    "Tasmania Standard Time" => "Australia/Hobart",
    "Vladivostok Standard Time" => "Asia/Vladivostok",
    "Lord Howe Standard Time" => "Australia/Lord_Howe",
    "Bougainville Standard Time" => "Pacific/Bougainville",
    "Russia Time Zone 10" => "Asia/Srednekolymsk",
    "Magadan Standard Time" => "Asia/Magadan",
    "Norfolk Standard Time" => "Pacific/Norfolk",
    "Sakhalin Standard Time" => "Asia/Sakhalin",
    "Central Pacific Standard Time" => "Pacific/Guadalcanal",
    "Russia Time Zone 11" => "Asia/Kamchatka",
    "New Zealand Standard Time" => "Pacific/Auckland",
    "UTC+12" => "Etc/GMT-12",
    "Fiji Standard Time" => "Pacific/Fiji",
    "Chatham Islands Standard Time" => "Pacific/Chatham",
    "UTC+13" => "Etc/GMT-13",
    "Tonga Standard Time" => "Pacific/Tongatapu",
    "Samoa Standard Time" => "Pacific/Apia",
    "Line Islands Standard Time" => "Pacific/Kiritimati"
  }

  @spec windows_to_olson(String.t()) :: String.t() | nil
  def windows_to_olson(name) do
    Map.get(@windows_to_olson, name)
  end
end
