defmodule Serverboards.Plugin do
  defstruct [
    name: nil,
    description: nil,
    author: nil,
    id: nil,
    version: nil,
    url: nil,
    status: ["disabled"],

    components: [],
    extra: %{},

    path: nil # set by parser/loader
  ]
end
