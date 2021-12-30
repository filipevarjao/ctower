defmodule Ctower.Discovery do
  use GenServer

  require Logger
  # iex --name node1@10.0.0.117 --cookie filipe -S mix
  # erl -name node2@10.0.0.198 -setcookie filipe
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Process.send_after(self(), :discovery, 1000)
    {:ok, Node.list()}
  end

  @impl true
  def handle_info(:discovery, state) do
    go_through_nodes(state)
    {:noreply, Node.list()}
  end

  defp go_through_nodes([]), do: :ok

  defp go_through_nodes([node | nodes]) do
    case :erpc.call(node, :erlang, :nodes, []) do
      [_ | _] = new_nodes -> maybe_connect(new_nodes)
      _ -> go_through_nodes(nodes)
    end
  end

  defp maybe_connect([]), do: :ok

  defp maybe_connect([node | nodes]) do
    case Enum.member?(Node.list(), node) do
      true ->
        :ok

      false ->
        :net_kernel.connect_node(node)
        |> case do
          true ->
            :ok

          false ->
            current_cookie = :erlang.get_cookie()
            return = :erpc.call(node, :erlang, :set_cookie, [current_cookie])
            Logger.info("#{return} when setting cookie to node #{node}")
        end
    end

    maybe_connect(nodes)
  end
end
