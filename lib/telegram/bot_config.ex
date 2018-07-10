defmodule Engine.Telegram.BotConfig do
  @moduledoc """
    A module that collects the parameters of bots
  """

  alias Agala.Provider.Telegram.Conn.ProviderParams

  @engine_telegram Application.get_env(:telegram_engine, Engine.Telegram)

  def get do
    %Agala.BotParams{
      name: Application.get_env(:sandbox, :agala_telegram)[:name],
      provider: Agala.Provider.Telegram,
      handler: Engine.Telegram.RequestHandler,
      provider_params: %ProviderParams{
        token: Application.get_env(:engine, :agala_telegram)[:token],
        poll_timeout: :infinity
      }
    }
  end

  def get(name, token) do
    @engine_telegram
    |> Keyword.get(:method)
    |> config(name, token)
  end

  defp config(:polling, name, token) do
    %Agala.BotParams{
      name: name,
      provider: Agala.Provider.Telegram,
      handler: Engine.Telegram.RequestHandler,
      provider_params: %ProviderParams{
        token: token,
        poll_timeout: :infinity,
        hackney_opts: parse_proxy()
      },
      private: %{
        http_opts: parse_proxy()
      }
    }
  end

  defp config(:webhook, name, token) do
    %Agala.BotParams{
      name: name,
      provider: Engine.Telegram.Provider,
      handler: Engine.Telegram.RequestHandler,
      provider_params: %ProviderParams{
        token: token,
        poll_timeout: :infinity
      }
    }
  end

  defp parse_proxy do
    @engine_telegram
    |> Keyword.get(:proxy)
    |> parse_proxy()
  end

  defp parse_proxy({:http, config}) do
    [proxy: config]
  end

  defp parse_proxy({:https, config}) do
    [proxy: config]
  end

  defp parse_proxy(_) do
    []
  end
end