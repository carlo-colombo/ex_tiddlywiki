defmodule TiddlywikiTest do
  use ExUnit.Case, async: true
  @moduletag tmp_dir: "mywiki"

  alias Tiddlywiki.Tiddler

  require Logger
  setup [:init_wiki, :start_wiki, :create_conf]

  describe "#get" do
    setup [:create_tiddlers]

    test "retrieve a tiddler by title", %{wikiconf: wikiconf} do
      {:ok, tiddler} =
        wikiconf
        |> Tiddlywiki.get("test tiddler 1")

      assert %Tiddlywiki.Tiddler{title: "test tiddler 1"} = tiddler
    end

    test "returns an error for a non existing tiddler", %{wikiconf: wikiconf} do
      assert {:error, :not_found} ==
               wikiconf
               |> Tiddlywiki.get("tiddler that does not exists")
    end
  end

  describe "#list" do
    setup [:create_tiddlers, :allow_filtering_tiddlers]

    test "lists all tiddlers", %{wikiconf: wikiconf} do
      {:ok, tiddlers} =
        wikiconf
        |> Tiddlywiki.list()

      [%Tiddlywiki.Tiddler{title: _} | _] = tiddlers
      Enum.all?(tiddlers, fn t -> match?(%Tiddlywiki.Tiddler{title: _}, t) end)
    end

    test "returns tiddlers matching the filter", %{wikiconf: wikiconf} do
      {:ok, tiddlers} =
        wikiconf
        |> Tiddlywiki.list(filter: "[tag[some tag]]")

      [%Tiddlywiki.Tiddler{title: "test tiddler"}] = tiddlers
    end
  end

  describe "#put" do
    test "creates a new tiddler", %{wikiconf: wikiconf} do
      :ok =
        wikiconf
        |> Tiddlywiki.put(%Tiddlywiki.Tiddler{
          title: "a new tiddler",
          fields: %{
            "a key" => "a value"
          }
        })

      assert {:ok,
              %Tiddler{
                fields: %{
                  "a key" => "a value"
                }
              }} =
               wikiconf
               |> Tiddlywiki.get("a new tiddler")
    end

    test "updates an existing tiddler", %{wikiconf: wikiconf} do
      :ok =
        wikiconf
        |> Tiddlywiki.put(%Tiddlywiki.Tiddler{title: "a new tiddler"})

      {:ok, _} =
        wikiconf
        |> Tiddlywiki.get("a new tiddler")

      assert :ok =
               wikiconf
               |> Tiddlywiki.put(%Tiddlywiki.Tiddler{title: "a new tiddler", tags: "some tag"})

      assert {:ok, %Tiddler{title: "a new tiddler", tags: "some tag"}} =
               wikiconf
               |> Tiddlywiki.get("a new tiddler")
    end
  end

  describe "#delete" do
    setup [:create_tiddlers]

    test "remove existing tiddlers", %{wikiconf: wikiconf} do
      assert :ok == Tiddlywiki.delete(wikiconf, "test tiddler 1")
      assert {:error, :not_found} == Tiddlywiki.get(wikiconf, "test tiddler 1")
    end

    test "returns :ok even if the tiddler does not exists", %{wikiconf: wikiconf} do
      assert :ok == Tiddlywiki.delete(wikiconf, "a tiddler that does not exists")
    end
  end

  # ===========================================================

  defp create_tiddlers(%{wikiconf: wikiconf}) do
    [
      "test tiddler 1",
      "test tiddler 2"
    ]
    |> Enum.each(fn title ->
      :ok =
        wikiconf
        |> Tiddlywiki.put(%Tiddlywiki.Tiddler{title: title})
    end)

    :ok =
      Tiddlywiki.put(wikiconf, %Tiddlywiki.Tiddler{
        title: "test tiddler",
        tags: "[[some tag]]"
      })
  end

  defp allow_filtering_tiddlers(%{wikiconf: wikiconf}) do
    :ok =
      wikiconf
      |> Tiddlywiki.put(%Tiddlywiki.Tiddler{
        title: "$:/config/Server/AllowAllExternalFilters",
        text: "yes"
      })
  end

  defp receive_messages(timeout, acc \\ []) do
    receive do
      {:stdout, _, "Serving on http://127.0.0.1:" <> port} ->
        String.trim(port)

      msg ->
        receive_messages(timeout, [msg | acc])
    after
      timeout ->
        {:error, [output: acc]}
    end
  end

  defp init_wiki(%{tmp_dir: wiki_dir}) do
    {:ok, _} =
      :exec.run("npx tiddlywiki '#{wiki_dir}' --init server", [:sync, :stdout, :stderr])

    :ok
  end

  defp start_wiki(%{tmp_dir: wiki_dir}) do
    username = "foo"
    password = "bar"

    {:ok, _, pid} =
      :exec.run(
        "npx \
              tiddlywiki #{wiki_dir} \
              --listen \
                port=0 \
                username=#{username} \
                password=#{password} ",
        [
          :stdout,
          {:kill, "pkill -P ${CHILD_PID}"},
          {:kill_timeout, 2}
        ]
      )

    on_exit(fn ->
      :exec.stop_and_wait(pid, 500)
    end)

    port = receive_messages(2000)

    Logger.info("wiki '#{wiki_dir}' listening at port :#{port} ")

    {:ok, port: port, username: username, password: password, wiki_dir: wiki_dir}
  end

  defp create_conf(%{port: port, username: username, password: password}) do
    wiki = String.to_atom("mywiki" <> port)

    Application.put_env(:tiddlywiki, wiki,
      base_url: "http://localhost:#{port}",
      username: username,
      password: password
    )

    {:ok, wikiconf: Tiddlywiki.new(wiki)}
  end
end
