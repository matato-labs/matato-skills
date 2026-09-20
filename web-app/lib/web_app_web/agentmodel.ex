defmodule WebAppWeb.AgentModel do
  def binary_value(value) when is_binary(value), do: value
  def binary_value(_value), do: nil

  def valid(%{"provider" => provider, "id" => id} = model)
      when is_binary(provider) and provider != "" and is_binary(id) and id != "",
      do: %{"provider" => provider, "id" => id, "name" => binary_value(model["name"]) || id}

  def valid(_model), do: nil

  def normalize(models), do: Enum.flat_map(models, &List.wrap(valid(&1)))

  def with_current(nil, models), do: models

  def with_current(model, models) do
    case valid(model) do
      nil -> models
      model -> if Enum.any?(models, &same_model?(&1, model)), do: models, else: [model | models]
    end
  end

  defp same_model?(candidate, model),
    do: candidate["id"] == model["id"] and candidate["provider"] == model["provider"]
end
