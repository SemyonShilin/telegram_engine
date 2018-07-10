defmodule Engine.Telegram.Spec do
  @moduledoc """
    Speck for a telegram to run engine in the supervisor
  """

  def engine_spec(bot_name, token) do
    [
      {Engine.Telegram, Engine.Telegram.BotConfig.get(bot_name, token)},
      {Agala.Bot, Engine.Telegram.BotConfig.get(bot_name, token)}
    ]
  end
end
