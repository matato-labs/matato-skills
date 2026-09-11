defmodule WebApp.OtelLogExporter do
  use GenServer

  @service_name "matato-pi-web"

  def start_link(endpoint), do: GenServer.start_link(__MODULE__, endpoint, name: __MODULE__)

  def export(level, message), do: GenServer.cast(__MODULE__, {:export, level, message})

  def payload(level, message, timestamp) do
    %{
      "resourceLogs" => [
        %{
          "resource" => %{
            "attributes" => [
              %{"key" => "service.name", "value" => %{"stringValue" => @service_name}}
            ]
          },
          "scopeLogs" => [
            %{
              "scope" => %{"name" => "web-app"},
              "logRecords" => [
                %{
                  "timeUnixNano" => Integer.to_string(timestamp),
                  "severityNumber" => severity_number(level),
                  "severityText" => level |> Atom.to_string() |> String.upcase(),
                  "body" => %{"stringValue" => IO.chardata_to_string(message)}
                }
              ]
            }
          ]
        }
      ]
    }
  end

  @impl true
  def init(endpoint), do: {:ok, endpoint}

  @impl true
  def handle_cast({:export, level, message}, endpoint) do
    Req.post(endpoint <> "/v1/logs",
      json: payload(level, message, System.system_time(:nanosecond))
    )

    {:noreply, endpoint}
  end

  defp severity_number(:debug), do: 5
  defp severity_number(:info), do: 9
  defp severity_number(:notice), do: 10
  defp severity_number(:warning), do: 13
  defp severity_number(:warn), do: 13
  defp severity_number(:error), do: 17
  defp severity_number(:critical), do: 21
  defp severity_number(:alert), do: 22
  defp severity_number(:emergency), do: 24
end
