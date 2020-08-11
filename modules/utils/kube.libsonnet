{
  convertObjectToList(o):: [o[n] for n in std.objectFields(o)],

  List(items):: {
    apiVersion: 'v1',
    kind: 'List',
    items: if std.type(items) == "object" then $.convertObjectToList(items) else items,
  },
}
