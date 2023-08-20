import EctoBox

defschema User do
  field(:id, :integer)
  field(:name, :string)
end

defschema UserMeta do
  field(:meta, EctoBox.Any)
end
