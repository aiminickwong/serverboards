defmodule Serverboards.Rules.Model do
  defmodule Rule do
    use Ecto.Schema
    schema "rules_rule" do
      field :uuid, Ecto.UUID
      field :is_active, :boolean
      field :deleted, :boolean
      field :name, :string
      field :description, :string
      field :project_id, :id

      field :service_id, :id

      field :trigger, :string
      field :params, :map

      field :from_template, :string

      field :last_state, :string

      timestamps()
    end

    @required_fields ~w(uuid is_active)a
    @optional_fields ~w(name description project_id service_id trigger params from_template last_state deleted)a
    def changeset(data, changes \\ :empty) do
      import Ecto.Changeset
      data
        |> cast(changes, @required_fields ++ @optional_fields)
        |> validate_required(@required_fields)
    end
  end

  defmodule ActionAtState do
    use Ecto.Schema
    schema "rules_action_state" do
      field :rule_id, :id
      field :state, :string

      field :action, :string
      field :params, :map
    end

    @required_fields ~w(rule_id state action params)a
    def changeset(data, changes \\ :empty) do
      import Ecto.Changeset
      data
        |> cast(changes, @required_fields)
        |> validate_required(@required_fields)
    end
  end

  defmodule RuleV2 do
    use Ecto.Schema
    schema "rules_rule_v2" do
      field :uuid, Ecto.UUID
      field :is_active, :boolean
      field :deleted, :boolean

      field :name, :string
      field :description, :string

      field :project_id, :id

      field :rule, :map
      field :from_template, :string

      timestamps()
    end
    @required_fields ~w(uuid is_active)a
    @optional_fields ~w(deleted name description project_id rule from_template)a
    def changeset(data, changes \\ :empty) do
      import Ecto.Changeset
      data
        |> cast(changes, @required_fields ++ @optional_fields)
        |> validate_required(@required_fields)
    end
  end

  defmodule RuleV2State do
    use Ecto.Schema
    schema "rules_rule_v2_state" do
      field :rule_id, :id
      field :state, :map

      timestamps()
    end
    @required_fields ~w(rule_id state)a
    @optional_fields ~w()a
    def changeset(data, changes \\ :empty) do
      import Ecto.Changeset
      data
        |> cast(changes, @required_fields ++ @optional_fields)
        |> validate_required(@required_fields)
    end
  end
end
