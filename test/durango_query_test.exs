defmodule DurangoQueryTest do
  use ExUnit.Case
  doctest Durango.Query
  require Durango.Query
  alias Durango.Query

  test "query can parse a for and return" do
    assert [
      for: p,
      in: :persons,
      return: p,
    ]
    |> Query.query()
    |> to_string == "FOR p IN persons RETURN p"
  end

  test "query can parse a for, filter, and return" do
    assert [
      for: p,
      in: :persons,
      filter: p.name == "willy",
      return: p
    ]
    |> Query.query()
    |> to_string == "FOR p IN persons FILTER p.name == \"willy\" RETURN p"
  end

  test "query can parse a for, limit, and return" do
    assert [
      for: p,
      in: :persons,
      limit: 10,
      return: p
    ]
    |> Query.query()
    |> to_string == "FOR p IN persons LIMIT 10 RETURN p"
  end

  test "query can parse a for, limit with a bound_var, and return" do
    counted = 10
    query = Query.query([
      for: p,
      in: :persons,
      limit: ^counted,
      return: p
    ])
    assert to_string(query) == "FOR p IN persons LIMIT @counted RETURN p"
    assert query.bound_variables == %{
      counted: %Durango.Dsl.BoundVar{key: :counted, validations: [], value: 10},
    }
  end

  test "query can parse a pinned/interpolated value in an expression" do
    min_age = 18
    query = Query.query([
      for: u,
      in: :users,
      filter: u.age >= ^min_age,
      return: u,
    ])
    assert to_string(query) == "FOR u IN users FILTER u.age >= @min_age RETURN u"
    assert query.bound_variables == %{min_age: %Durango.Dsl.BoundVar{key: :min_age, validations: [], value: 18}}
  end

  test "query can parse a dot_access return value" do
    query = Query.query([
      for: u,
      in: :users,
      filter: u.age >= 18,
      return: u.age,
    ])
    assert to_string(query) == "FOR u IN users FILTER u.age >= 18 RETURN u.age"
    assert query.bound_variables == %{}
  end


  test "query can parse a map return value" do
    query = Query.query([
      for: u,
      in: :users,
      filter: u.age >= 18,
      return: %{age: u.age, name: u.first_name},
    ])
    assert to_string(query) == "FOR u IN users FILTER u.age >= 18 RETURN { age: u.age, name: u.first_name }"
    assert query.bound_variables == %{}
  end

  test "query can parse a return document" do
    query = Query.query([
      return: document("123"),
    ])
    assert to_string(query) == ~s/RETURN DOCUMENT("123")/
    assert query.bound_variables == %{}
  end


  test "query can parse a `for: a in :things` type of query" do
    q = Query.query([for: a in :thing, return: a])
    assert to_string(q) == "FOR a IN thing RETURN a"
  end
  @tag current: true
  test "query can parse a multi-variable for expression" do
    q = Query.query([
      for: {a, b, c} in :things,
        return: %{a: a, b: b, c: c}
    ])
    assert to_string(q) == "FOR a, b, c IN things RETURN { a: a, b: b, c: c }"
    assert q.local_variables == [:c, :b, :a]
  end

  test "query can parse a long query" do
    expected = """
      FOR meetup IN meetups
        FILTER "NOSQL" IN meetup.topics
        FOR city IN OUTBOUND meetup held_in
          FOR programmer IN INBOUND city lives_in
            FILTER programmer.notify
            FOR cname IN city_names
              FILTER cname.city == city._key AND cname.lang == programmer.lang
              INSERT { email: programmer.email, meetup: meetup._key, city: cname.name }
              INTO invitations
    """
    |> String.replace(~r/\s{1,}/, " ")
    |> String.trim

    q = Query.query([
      for: meetup, in: :meetups,
        filter: "NOSQL" in meetup.topics,
        for: city, in_outbound: {meetup, :held_in},
          for: programmer, in_inbound: {city, :lives_in},
            filter: programmer.notify,
            for: cname, in: :city_names,
              filter: cname.city == city._key and cname.lang == programmer.lang,
              insert: %{
                email: programmer.email,
                meetup: meetup._key,
                city: cname.name,
              },
              into: :invitations
    ])
    assert to_string(q) == expected
  end

  test "query can parse another long query" do
    expected = """
        FOR v, e, p IN 1..5 OUTBOUND "circles/A" GRAPH "traversalGraph"
      FILTER p.edges[0].theTruth == true
         AND p.edges[1].theFalse == false
      FILTER p.vertices[1]._key == "G"
      RETURN p
    """
    |> String.replace(~r/\s+/, " ")
    |> String.trim
    q = Query.query([
      for: {v, e, p} in 1..5,
      outbound: "circles/A",
      graph: "traversalGraph",
      filter: p.edges[0].theTruth == true and p.edges[1].theFalse == false,
      filter: p.vertices[1]._key == "G",
      return: p
    ])
    assert to_string(q) == expected

  end

end
