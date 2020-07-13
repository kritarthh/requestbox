defmodule Requestbox.Request do
  defmodule Header do
    @derive {Jason.Encoder, only: [:name, :value]}
    defstruct [:name, :value]

    defmodule Type do
      use OK.Pipe
      require OK
      alias Requestbox.Request.Header
      import Maptu, only: [strict_struct: 2]

      @behaviour Ecto.Type
      def type, do: :text

      def cast(%Header{} = header), do: OK.success(header)
      def cast(%{} = header), do: strict_struct(Header, header)

      def load(value), do: Jason.decode(value) ~>> cast
      def dump(value), do: Jason.encode(value)
    end
  end

  # defimpl Jason.Encoder, for: Header do
  #   def encode(value, opts) do
  #     Jason.Encode.map(
  #       Map.take(value, [:name, :value])
  #       |> Enum.map(fn x -> elem(x, 1) end)
  #       |> Enum.chunk_every(2)
  #       |> Map.new(fn [k, v] -> {k, v} end),
  #       opts
  #     )
  #   end
  # end

  defmodule Headers do
    defmodule Type do
      use OK.Pipe
      require OK
      alias Requestbox.Request.Header

      @behaviour Ecto.Type
      def type, do: :text

      def cast(headers) when is_list(headers) do
        OK.map_all(headers, &Header.Type.cast/1)
      end

      def load(value), do: Jason.decode(value) ~>> cast
      def dump(value), do: Jason.encode(value)
    end
  end

  use Requestbox.Web, :model
  use Requestbox.HashID

  alias Requestbox.Request.Headers
  alias Requestbox.Session

  # @derive {Jason.Encoder, only: [:method, :client_ip, :path, :query_string, :headers, :body]}
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "requests" do
    field(:method, :string)
    field(:client_ip, :string)
    field(:path, :string)
    field(:query_string, :string)
    field(:form_data, :string)
    field(:headers, Headers.Type)
    field(:body, :string)

    belongs_to(:session, Session)
    timestamps()
  end

  defimpl Jason.Encoder, for: Requestbox.Request do
    def encode(value, opts) do
      Jason.Encode.map(
        Map.take(value, [:method, :client_ip, :path, :query_string, :form_data, :headers, :body])
        |> Map.update!(:headers, fn headers -> Enum.reduce(headers, %{}, fn(x, acc) -> Map.put_new(acc, x.name, x.value) end) end)
        |> Map.update!(:form_data, fn form_data -> Jason.decode!(form_data) |> Enum.reduce([], fn({k, v}, acc) -> acc ++ [[k, v]] end) end)
        |> Map.update!(:query_string, fn query_string ->
          URI.query_decoder(query_string)
          |> Enum.reduce(%{}, fn({k, v}, acc) -> Map.merge(acc, %{k => v}) end)
        end),
        opts
      )
    end
  end

  encode_param(Requestbox.Request, :session_id, &Session.encode/1)

  @required_fields [:method, :path]
  @optional_fields [:client_ip, :headers, :body, :query_string]

  @doc """
  Creates a changeset based on the `struct` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> cast_assoc(:session)
    |> validate_required(@required_fields)
  end

  def sorted(query \\ Requestbox.Request) do
    query |> order_by([r], desc: r.inserted_at)
  end
end
