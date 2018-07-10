defmodule Engine.TelegramTest do
  use ExUnit.Case
  doctest Engine.Telegram

  test "greets the world" do
    assert Engine.Telegram.hello() == :world
  end
end
