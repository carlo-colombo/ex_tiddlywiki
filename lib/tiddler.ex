defmodule Tiddlywiki.Tiddler do
  @moduledoc """
    Struct representing a tiddler
  """

  @derive Jason.Encoder
  defstruct [
    :title,
    :tags,
    :modified,
    :created,
    :text,
    :creator,
    :modifier,
    :fields,
    :type,
    :bag,
    :permissions,
    :recipe,
    :revision,
    :uri
  ]

  @type t :: %Tiddlywiki.Tiddler{
          title: String.t(),
          tags: String.t(),
          modified: String.t(),
          created: String.t(),
          type: String.t(),
          text: String.t()
        }
end
