defmodule ICalendar.Event do
  @moduledoc """
  Calendars have events.
  """

  @type t :: %__MODULE__{
          summary: String.t() | nil,
          dtstart: DateTime.t() | NaiveDateTime.t() | nil,
          dtend: DateTime.t() | NaiveDateTime.t() | nil,
          rrule: map() | nil,
          exdates: [DateTime.t()],
          description: String.t() | nil,
          location: String.t() | nil,
          url: String.t() | nil,
          uid: String.t() | nil,
          prodid: String.t() | nil,
          status: String.t() | nil,
          categories: [String.t()] | nil,
          class: String.t() | nil,
          comment: String.t() | nil,
          geo: {float(), float()} | nil,
          modified: DateTime.t() | nil,
          organizer: String.t() | nil,
          sequence: String.t() | integer() | nil,
          attendees: [map()]
        }

  defstruct summary: nil,
            dtstart: nil,
            dtend: nil,
            rrule: nil,
            exdates: [],
            description: nil,
            location: nil,
            url: nil,
            uid: nil,
            prodid: nil,
            status: nil,
            categories: nil,
            class: nil,
            comment: nil,
            geo: nil,
            modified: nil,
            organizer: nil,
            sequence: nil,
            attendees: []

  @valid_statuses ~w(tentative confirmed cancelled)
  @valid_classes ~w(public private confidential)

  @doc """
  Validates an event's fields and returns `{:ok, event}` or
  `{:error, errors}` where `errors` is a list of error strings.

  Checks performed:

    * `dtstart` and `dtend`, if set, must be `DateTime` or `NaiveDateTime`
    * if both are set, `dtend` must not be before `dtstart`
    * `status`, if set, must be one of: tentative, confirmed, cancelled
    * `class`, if set, must be one of: public, private, confidential
    * `geo`, if set, must be a `{lat, lon}` tuple of floats
    * `categories`, if set, must be a list of strings
    * `url`, if set, must be a string
  """
  @spec validate(t()) :: {:ok, t()} | {:error, [String.t()]}
  def validate(%__MODULE__{} = event) do
    errors =
      []
      |> validate_datetime(:dtstart, event.dtstart)
      |> validate_datetime(:dtend, event.dtend)
      |> validate_date_order(event.dtstart, event.dtend)
      |> validate_status(event.status)
      |> validate_class(event.class)
      |> validate_geo(event.geo)
      |> validate_categories(event.categories)
      |> validate_string(:url, event.url)

    case errors do
      [] -> {:ok, event}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_datetime(errors, _field, nil), do: errors
  defp validate_datetime(errors, _field, %DateTime{}), do: errors
  defp validate_datetime(errors, _field, %NaiveDateTime{}), do: errors

  defp validate_datetime(errors, field, _value),
    do: ["#{field} must be a DateTime or NaiveDateTime" | errors]

  defp validate_date_order(errors, nil, _), do: errors
  defp validate_date_order(errors, _, nil), do: errors

  defp validate_date_order(errors, %DateTime{} = dtstart, %DateTime{} = dtend) do
    if DateTime.compare(dtend, dtstart) == :lt do
      ["dtend must not be before dtstart" | errors]
    else
      errors
    end
  end

  defp validate_date_order(errors, %NaiveDateTime{} = dtstart, %NaiveDateTime{} = dtend) do
    if NaiveDateTime.compare(dtend, dtstart) == :lt do
      ["dtend must not be before dtstart" | errors]
    else
      errors
    end
  end

  defp validate_date_order(errors, _, _), do: errors

  defp validate_status(errors, nil), do: errors

  defp validate_status(errors, status) when is_binary(status) do
    if String.downcase(status) in @valid_statuses do
      errors
    else
      ["status must be one of: #{Enum.join(@valid_statuses, ", ")}" | errors]
    end
  end

  defp validate_status(errors, _), do: ["status must be a string" | errors]

  defp validate_class(errors, nil), do: errors

  defp validate_class(errors, class) when is_binary(class) do
    if String.downcase(class) in @valid_classes do
      errors
    else
      ["class must be one of: #{Enum.join(@valid_classes, ", ")}" | errors]
    end
  end

  defp validate_class(errors, _), do: ["class must be a string" | errors]

  defp validate_geo(errors, nil), do: errors

  defp validate_geo(errors, {lat, lon}) when is_float(lat) and is_float(lon), do: errors
  defp validate_geo(errors, {lat, lon}) when is_number(lat) and is_number(lon), do: errors

  defp validate_geo(errors, _),
    do: ["geo must be a {latitude, longitude} tuple of numbers" | errors]

  defp validate_categories(errors, nil), do: errors
  defp validate_categories(errors, categories) when is_list(categories), do: errors
  defp validate_categories(errors, _), do: ["categories must be a list of strings" | errors]

  defp validate_string(errors, _field, nil), do: errors
  defp validate_string(errors, _field, value) when is_binary(value), do: errors
  defp validate_string(errors, field, _), do: ["#{field} must be a string" | errors]
end

defimpl ICalendar.Serialize, for: ICalendar.Event do
  alias ICalendar.Util.KV

  def to_ics(event, _options \\ []) do
    contents = to_kvs(event)

    """
    BEGIN:VEVENT
    #{contents}END:VEVENT
    """
  end

  defp to_kvs(event) do
    event
    |> Map.from_struct()
    |> Enum.map(&to_kv/1)
    |> List.flatten()
    |> Enum.sort()
    |> Enum.join()
  end

  defp to_kv({:exdates, value}) when is_list(value) do
    case value do
      [] ->
        ""

      exdates ->
        exdates
        |> Enum.map(&KV.build("EXDATE", &1))
    end
  end

  defp to_kv({key, value}) do
    name = key |> to_string |> String.upcase()
    KV.build(name, value)
  end
end
