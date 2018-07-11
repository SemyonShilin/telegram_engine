defmodule Engine.Telegram do
  @moduledoc """
    The module set webhook for the telegram bots and sends custom messages
  """

  alias Agala.{BotParams, Conn}
  alias Agala.Bot.Handler
  alias Engine.Telegram.{MessageSender, RequestHandler}
  use Agala.Provider.Telegram, :handler
  alias Engine.BotLogger

  use GenServer

  @certificate     :agala_telegram  |> Application.get_env(:certificate)
  @url             :agala_telegram  |> Application.get_env(:url)
  @engine_telegram :telegram_engine |> Application.get_env(Engine.Telegram)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: :"#Engine.Telegram::#{opts.name}"])
  end

  def init(opts) do
    method = Keyword.get(@engine_telegram, :method)
    case method do
      :webhook -> set_webhook(opts)
      :polling -> nil
      _ -> nil
    end

    BotLogger.info("Telegram bot #{opts.name} started. Method: #{method}")

    {:ok, opts}
  end

  def message_pass(bot_name, hub, message) do
    GenServer.cast(:"#Engine.Telegram::#{bot_name}", {:message, hub, message})
  end

  def message_pass(bot_name, message) do
    GenServer.cast(:"#Engine.Telegram::#{bot_name}", {:message, message})
  end

  def pre_down(bot_name) do
    GenServer.call(:"#Engine.Telegram::#{bot_name}", :delete_webhook)
  end

  def handle_call(:delete_webhook, _from, state) do
    case Keyword.get(@engine_telegram, :method) do
      :webhook ->  delete_webhook(state) |> BotLogger.info()
      :polling -> BotLogger.info("Nothing to do because method polling")
      _ -> BotLogger.info( "Nothing to do")
    end
    {:reply, :ok, state}
  end

  def handle_cast({:message, message}, state) do
    Handler.handle(message, state)
    {:noreply, state}
  end

  def handle_cast({:message, _hub, %{"data" => %{"messages" => messages, "chat" => %{"id" => id}}} =  _message}, state) do
    messages
    |> RequestHandler.parse_hub_response()
    |> Enum.filter(& &1)
    |> MessageSender.delivery(id, state)

    {:noreply, state}
  end

  def set_webhook(%BotParams{name: bot_name} = params) do
    conn = %Conn{request_bot_params: params} |> Conn.send_to(bot_name)

    HTTPoison.post(
      set_webhook_url(conn),
      webhook_upload_body(conn),
      [{"Content-Type", "application/json"}]
    )
    |> parse_body
#    |> resolve_updates(params)
  end

  def delete_webhook(%BotParams{name: bot_name} = params) do
    conn = %Conn{request_bot_params: params} |> Conn.send_to(bot_name)

    HTTPoison.post(
      delete_webhook_url(conn),
      [],
      [{"Content-Type", "application/json"}]
    )
    |> parse_body
    |> resolve_updates(params)
  end

  def base_url(conn) do
    "https://api.telegram.org/bot" <> conn.request_bot_params.provider_params.token
  end

  def set_webhook_url(conn) do
    base_url(conn) <> "/setWebhook"
  end

  def delete_webhook_url(conn) do
    base_url(conn) <> "/deleteWebhook"
  end

  defp create_body(map, opts) when is_map(map) do
    Map.merge(map, Enum.into(opts, %{}), fn _, v1, _ -> v1 end)
  end

  defp create_body_multipart(map, opts) when is_map(map) do
    multipart =
      map
      |> create_body(opts)
      |> Enum.map(fn
        {key, {:file, file}} ->
          {:file, file, {"form-data", [{:name, key}, {:filename, Path.basename(file)}]}, []}
        {key, value} -> {to_string(key), to_string(value)}
      end)
    {:multipart, multipart}
  end

  defp webhook_upload_body(conn, opts \\ []) do
    case @certificate do
      nil  -> %{url: server_webhook_url(conn)}
      path -> %{certificate: {:file, path},
                url: server_webhook_url(conn)}
    end
    |> create_body_multipart(opts)
  end

  defp parse_body({:ok, resp = %HTTPoison.Response{body: body}}),
       do: {:ok, %HTTPoison.Response{resp | body: Poison.decode!(body)}}

  defp parse_body(default), do: default

  defp server_webhook_url(conn),
       do: @url || "" <> conn.request_bot_params.provider_params.token

  defp resolve_updates(
         {
           :ok,
           %HTTPoison.Response{
             status_code: 200,
             body: %{"ok" => true, "result" => true, "description" => description}
           }
         },
         _bot_params
       ), do: description

  defp resolve_updates(
         {
           :ok,
           %HTTPoison.Response{
             status_code: 200,
             body: %{"ok" => true, "result" => result}
           }
         },
         bot_params
       ), do: bot_params
end
