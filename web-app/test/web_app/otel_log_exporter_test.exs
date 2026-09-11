defmodule WebApp.OtelLogExporterTest do
  use ExUnit.Case, async: true

  test "formats application logs as OTLP JSON" do
    assert WebApp.OtelLogExporter.payload(:warning, "Automations reloaded", 123) == %{
             "resourceLogs" => [
               %{
                 "resource" => %{
                   "attributes" => [
                     %{
                       "key" => "service.name",
                       "value" => %{"stringValue" => "matato-pi-web"}
                     }
                   ]
                 },
                 "scopeLogs" => [
                   %{
                     "scope" => %{"name" => "web-app"},
                     "logRecords" => [
                       %{
                         "timeUnixNano" => "123",
                         "severityNumber" => 13,
                         "severityText" => "WARNING",
                         "body" => %{"stringValue" => "Automations reloaded"}
                       }
                     ]
                   }
                 ]
               }
             ]
           }
  end
end
