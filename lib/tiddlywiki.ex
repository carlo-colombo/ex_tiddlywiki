defmodule Tiddlywiki do
  @moduledoc """

  """
  alias Tiddlywiki.Tiddler
  require Logger

  defmodule Conf do
    defstruct [
      :url,
      :external_url,
      :username,
      :password
    ]

    @type t :: %Tiddlywiki.Conf{
            url: String.t(),
            external_url: String.t(),
            username: String.t(),
            password: String.t()
          }
  end

  defstruct [:req]

  @type t :: %Tiddlywiki{
          req: Req.Request.t()
        }

  defp transform_to_tiddler_field(tiddler_fields, input) do
    if Enum.member?(tiddler_fields, input) do
      String.to_existing_atom(input)
    else
      input
    end
  end


  @doc """
  Returns a new Tiddywiki struct.

  See `list/2`, `get/2`, `delete/2` and `put/2` to interact with a TiddlyWiki server instance

  Add to your config oen or more wiki alias, the alias is used to retrieve the matching configuration

      config :tiddlywiki, :wiki_alias,
        base_url: "http://example.com",
        username: "bot",
        password: "pwd"
  """
  @spec new(atom()) :: Tiddlywiki.t()
  def new(wiki) do
    conf = Application.get_env(:tiddlywiki, wiki)

    tiddler_fields =
      Map.keys(%Tiddler{})
      |> Enum.map(&Atom.to_string/1)

    req =
      [
        base_url: conf[:base_url],
        auth: {:basic, conf[:username] <> ":" <> conf[:password]},
        decode_json: [
          keys: &transform_to_tiddler_field(tiddler_fields, &1)
        ]
      ]
      |> Req.new()
      |> Req.Request.append_response_steps(
        log_response: fn {req, resp} ->
          method = String.upcase(Atom.to_string(req.method), :default)

          Logger.info("#{method} #{URI.to_string(req.url)} #{resp.status}",
            method: method,
            status: resp.status,
            path: req.url.path,
            query: req.url.query
          )

          {req, resp}
        end
      )

    %Tiddlywiki{req: req}
  end

  @type list_options :: [
          filter: String.t()
        ]

  @doc """
  List tiddlers, optionally filtering using a Tiddlywiki filter

      :mywiki
      |> Tiddlywiki.new()
      |> Tiddlywiki.list()

      :mywiki
      |> Tiddlywiki.new()
      |> Tiddlywiki.list(filter: "[tag[some tag]]")

  """
  @spec list(Conf.t(), list_options()) :: {:ok, [Tiddler.t()]}
  def list(wikiconf, options \\ []) do
    resp =
      wikiconf.req
      |> Req.get!(
        url: "/recipes/default/tiddlers.json",
        params: options
      )

    200 = resp.status

    {:ok, resp.body |> Enum.map(&struct(Tiddler, &1))}
  end

  @doc """
  Retrieve tiddler by title

      :mywiki
      |> Tiddlywiki.new()
      |> Tiddlywiki.get("test tiddler")

  """
  @spec get(wikiconf :: Conf.t(), title :: String.t()) ::
          {:ok, Tiddler.t()} | {:error, :not_found}
  def get(wikiconf, title) do
    resp =
      wikiconf.req
      |> Req.get!(url: "/recipes/default/tiddlers/#{encode(title)}")

    if resp.status == 200 do
      {:ok, struct(Tiddler, resp.body)}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Creates or updates, returns :ok if successfull

      :mywiki
      |> Tiddlywiki.new()
      |> Tiddlywiki.put(%Tiddler{
        title: "a new tiddler",
        tags: "[[with space]] spaceless"
      })
  """
  def put(wikiconf, tiddler) do
    resp =
      wikiconf.req
      |> add_requested_with_header
      |> Req.put!(url: "/recipes/default/tiddlers/#{encode(tiddler.title)}", json: tiddler)

    204 = resp.status

    :ok
  end

  @doc """
  Delete a tiddler by title, if succefull returns `:ok`

      :mywiki
      |> Tiddlywiki.new()
      |> Tiddlywiki.delete("tiddler to delete")
  """
  def delete(wikiconf, title) do
    wikiconf.req
    |> add_requested_with_header
    |> Req.delete!(url: "/bags/default/tiddlers/#{encode(title)}")

    :ok
  end

  # ======================================================================

  defp encode(s) do
    URI.encode(s, fn
      ?: -> false
      ?/ -> false
      c -> URI.char_unescaped?(c)
    end)
  end

  alias Req.Request

  defp add_requested_with_header(req),
    do:
      Request.append_request_steps(req,
        header: &Request.put_header(&1, "x-requested-with", "TiddlyWiki")
      )
end
