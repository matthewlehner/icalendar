defmodule ICalendar.DateHelperTest do
  use ExUnit.Case

  alias ICalendar.DateHelper

  doctest ICalendar.DateHelper

  describe "shift/2 with days" do
    test "shifts a UTC datetime forward by days" do
      dt = ~U[2020-01-15 10:00:00Z]
      assert DateHelper.shift(dt, days: 1) == ~U[2020-01-16 10:00:00Z]
    end

    test "shifts a UTC datetime backward by days" do
      dt = ~U[2020-01-15 10:00:00Z]
      assert DateHelper.shift(dt, days: -3) == ~U[2020-01-12 10:00:00Z]
    end

    test "shifts across month boundary" do
      dt = ~U[2020-01-31 12:00:00Z]
      assert DateHelper.shift(dt, days: 1) == ~U[2020-02-01 12:00:00Z]
    end

    test "shifts across year boundary" do
      dt = ~U[2020-12-31 23:00:00Z]
      assert DateHelper.shift(dt, days: 1) == ~U[2021-01-01 23:00:00Z]
    end

    test "shifting by zero days returns the same datetime" do
      dt = ~U[2020-06-15 08:00:00Z]
      assert DateHelper.shift(dt, days: 0) == dt
    end

    test "shifts a NaiveDateTime by days" do
      naive = ~N[2020-03-10 14:30:00]
      assert DateHelper.shift(naive, days: 5) == ~N[2020-03-15 14:30:00]
    end
  end

  describe "shift/2 with months" do
    test "shifts forward by one month" do
      dt = ~U[2020-01-15 10:00:00Z]
      assert DateHelper.shift(dt, months: 1) == ~U[2020-02-15 10:00:00Z]
    end

    test "shifts backward by months" do
      dt = ~U[2020-03-15 10:00:00Z]
      assert DateHelper.shift(dt, months: -2) == ~U[2020-01-15 10:00:00Z]
    end

    test "clamps day when target month is shorter" do
      dt = ~U[2020-01-31 10:00:00Z]
      assert DateHelper.shift(dt, months: 1) == ~U[2020-02-29 10:00:00Z]
    end

    test "clamps day for non-leap year February" do
      dt = ~U[2021-01-31 10:00:00Z]
      assert DateHelper.shift(dt, months: 1) == ~U[2021-02-28 10:00:00Z]
    end

    test "shifts across year boundary forward" do
      dt = ~U[2020-11-15 10:00:00Z]
      assert DateHelper.shift(dt, months: 3) == ~U[2021-02-15 10:00:00Z]
    end

    test "shifts across year boundary backward" do
      dt = ~U[2021-02-15 10:00:00Z]
      assert DateHelper.shift(dt, months: -3) == ~U[2020-11-15 10:00:00Z]
    end

    test "shifts a NaiveDateTime by months" do
      naive = ~N[2020-01-31 12:00:00]
      assert DateHelper.shift(naive, months: 1) == ~N[2020-02-29 12:00:00]
    end
  end

  describe "shift/2 with years" do
    test "shifts forward by one year" do
      dt = ~U[2020-06-15 10:00:00Z]
      assert DateHelper.shift(dt, years: 1) == ~U[2021-06-15 10:00:00Z]
    end

    test "shifts backward by years" do
      dt = ~U[2021-06-15 10:00:00Z]
      assert DateHelper.shift(dt, years: -1) == ~U[2020-06-15 10:00:00Z]
    end

    test "clamps leap day to Feb 28 in non-leap year" do
      dt = ~U[2020-02-29 10:00:00Z]
      assert DateHelper.shift(dt, years: 1) == ~U[2021-02-28 10:00:00Z]
    end

    test "shifts a NaiveDateTime by years" do
      naive = ~N[2020-02-29 12:00:00]
      assert DateHelper.shift(naive, years: 1) == ~N[2021-02-28 12:00:00]
    end
  end

  describe "shift/2 with combined options" do
    test "applies years, months, and days together" do
      dt = ~U[2020-01-15 10:00:00Z]
      assert DateHelper.shift(dt, years: 1, months: 2, days: 3) == ~U[2021-03-18 10:00:00Z]
    end
  end

  describe "shift/2 with timezone-aware datetimes" do
    test "preserves wall clock time across DST spring-forward" do
      # 2020-03-08 is DST spring-forward in America/Chicago (2:00 AM -> 3:00 AM)
      # Shifting from March 7 by 1 day should land on March 8, still at 10:00 AM
      dt = DateTime.from_naive!(~N[2020-03-07 10:00:00], "America/Chicago")
      shifted = DateHelper.shift(dt, days: 1)

      assert shifted.hour == 10
      assert shifted.day == 8
      assert shifted.time_zone == "America/Chicago"
    end

    test "preserves wall clock time across DST fall-back" do
      # 2020-11-01 is DST fall-back in America/Chicago (2:00 AM -> 1:00 AM)
      # Shifting from Oct 31 by 1 day should land on Nov 1, still at 10:00 AM
      dt = DateTime.from_naive!(~N[2020-10-31 10:00:00], "America/Chicago")
      shifted = DateHelper.shift(dt, days: 1)

      assert shifted.hour == 10
      assert shifted.day == 1
      assert shifted.month == 11
      assert shifted.time_zone == "America/Chicago"
    end

    test "handles ambiguous time by picking post-transition" do
      # 2020-11-01 01:30 AM is ambiguous in America/Chicago (CDT and CST)
      # Shifting from Oct 31 01:30 by 1 day should resolve to CST (post-transition)
      dt = DateTime.from_naive!(~N[2020-10-31 01:30:00], "America/Chicago")
      shifted = DateHelper.shift(dt, days: 1)

      assert shifted.hour == 1
      assert shifted.minute == 30
      assert shifted.day == 1
      assert shifted.month == 11
      # Post-transition is CST (UTC-6), std_offset == 0
      assert shifted.std_offset == 0
    end

    test "handles gap time by picking post-gap" do
      # 2020-03-08 02:30 AM doesn't exist in America/Chicago (spring-forward)
      # Shifting from March 7 02:30 by 1 day should resolve to the first valid
      # time after the gap: 03:00 CDT
      dt = DateTime.from_naive!(~N[2020-03-07 02:30:00], "America/Chicago")
      shifted = DateHelper.shift(dt, days: 1)

      assert shifted.hour == 3
      assert shifted.minute == 0
      assert shifted.day == 8
      assert shifted.time_zone == "America/Chicago"
      # Post-gap is CDT (UTC-5), std_offset == 3600
      assert shifted.std_offset == 3600
    end
  end

  describe "windows_to_olson/1" do
    test "converts common Windows timezone names" do
      assert DateHelper.windows_to_olson("Eastern Standard Time") == "America/New_York"
      assert DateHelper.windows_to_olson("Central Standard Time") == "America/Chicago"
      assert DateHelper.windows_to_olson("Pacific Standard Time") == "America/Los_Angeles"
      assert DateHelper.windows_to_olson("Mountain Standard Time") == "America/Denver"
    end

    test "converts Greenwich Standard Time" do
      assert DateHelper.windows_to_olson("Greenwich Standard Time") == "Atlantic/Reykjavik"
    end

    test "converts UTC" do
      assert DateHelper.windows_to_olson("UTC") == "Etc/UTC"
    end

    test "converts European timezone names" do
      assert DateHelper.windows_to_olson("W. Europe Standard Time") == "Europe/Berlin"
      assert DateHelper.windows_to_olson("Romance Standard Time") == "Europe/Paris"
      assert DateHelper.windows_to_olson("GMT Standard Time") == "Europe/London"
    end

    test "converts Asia-Pacific timezone names" do
      assert DateHelper.windows_to_olson("Tokyo Standard Time") == "Asia/Tokyo"
      assert DateHelper.windows_to_olson("China Standard Time") == "Asia/Shanghai"
      assert DateHelper.windows_to_olson("AUS Eastern Standard Time") == "Australia/Sydney"
      assert DateHelper.windows_to_olson("New Zealand Standard Time") == "Pacific/Auckland"
    end

    test "returns nil for unknown timezone names" do
      assert DateHelper.windows_to_olson("Unknown Zone") == nil
      assert DateHelper.windows_to_olson("Not A Real Timezone") == nil
    end
  end
end
