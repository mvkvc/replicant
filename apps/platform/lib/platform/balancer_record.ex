defmodule Platform.BalancerRecord do
  defstruct [:id, :model, :status, :node]

  def to_ets(%__MODULE__{} = record) do
    {record.id, record.model, record.status, record.node}
  end

  def from_ets({id, model, status, node}) do
    %__MODULE__{id: id, model: model, status: status, node: node}
  end

  def dump(table) do
    Enum.map(:ets.tab2list(table), &from_ets/1)
  end

  def insert(table, records) do
    :ets.insert(table, Enum.map(records, &to_ets/1))
  end

  def delete(table, id) do
    :ets.delete(table, id)
  end

  def update(table, id, field, value) do
    postion =
      case field do
        :model -> 2
        :status -> 3
        :node -> 4
        _ -> nil
      end

    case postion do
      nil -> false
      position -> :ets.update_element(table, id, {position, value})
    end
  end

  def lookup(table, id) do
    case :ets.lookup(table, id) do
      [record] -> from_ets(record)
      _ -> nil
    end
  end

  def match_spec(opts, operation) when operation in [:select, :delete] do
    model = Keyword.get(opts, :model, :"$2")
    status = Keyword.get(opts, :status, :"$3")
    node = Keyword.get(opts, :node, :"$4")
    node_eq = Keyword.get(opts, :node_eq, nil)
    node_neq = Keyword.get(opts, :node_neq, nil)

    guards = []
    guards = if node_eq, do: [{:==, :"$4", node_eq} | guards], else: guards
    guards = if node_neq, do: [{:"/=", :"$4", node_neq} | guards], else: guards

    result =
      case operation do
        :select -> [:"$_"]
        :delete -> [true]
      end

    [
      {{:"$1", model, status, node}, guards, result}
    ]
  end

  def select(table, opts \\ []) do
    match_spec = match_spec(opts, :select)

    Enum.map(:ets.select(table, match_spec), &from_ets/1)
  end

  def select_delete(table, opts \\ []) do
    match_spec = match_spec(opts, :delete)

    :ets.select_delete(table, match_spec)
  end
end
