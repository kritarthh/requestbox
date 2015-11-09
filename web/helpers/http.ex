defmodule Requestbox.Helpers.HTTP do

  def color_method("GET"), do: "label-success"
  def color_method("POST"), do: "label-primary"
  def color_method("PUT"), do: "label-info"
  def color_method("PATCH"), do: "label-warning"
  def color_method("DELETE"), do: "label-danger"
  def color_method(_), do: "label-default"

  def header_separator(_index = 0), do: "?"
  def header_separator(_index), do: "&"

  def query_parts(query_string) do
    URI.query_decoder(query_string)
  end

  def header_case(_header = "dnt"), do: "DNT"
  def header_case(header) do
    String.split(header, "-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("-")
  end

  defmacro __using__(_) do
    quote do: import Requestbox.Helpers.HTTP
  end
end
