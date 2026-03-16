defmodule ICalendar.Property do
  @moduledoc """
  Provide structure to define properties of an Event.
  """

  @type t :: %__MODULE__{
          key: String.t() | nil,
          value: String.t() | nil,
          params: map()
        }

  defstruct key: nil,
            value: nil,
            params: %{}
end
