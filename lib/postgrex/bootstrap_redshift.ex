defmodule Postgrex.Bootstrap.Redshift do
  @moduledoc """
  Handles custom bootstrap required for Redshift.

  In order to use Redshift, add the following to your Repo config:

      bootstrap_module: Postgrex.Bootstrap.Redshift
  """

  @doc false
  def bootstrap_query(m, version) do
    if version >= {9, 2, 0} do
      rngsubtype = "coalesce(r.rngsubtype, 0)"
      join_range = "LEFT JOIN pg_range AS r ON r.rngtypid = t.oid"
    else
      rngsubtype = "0"
      join_range = ""
    end

    # This is hacked to work with Redshift - Redshift doesn't support array constructor syntax, so use lists instead.
    # Casting to TEXT isn't supported in Redshift - look up typsend regproc by OID instead
    # The other previous 'where' filters may still be needed - I just didn't understand enough about either
    # Redshift or Postgres to make them work

    """
    SELECT t.oid, t.typname, t.typsend, t.typreceive, t.typoutput, t.typinput,
           t.typelem, #{rngsubtype}, ARRAY (
      SELECT a.atttypid
      FROM pg_attribute AS a
      WHERE a.attrelid = t.typrelid AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY a.attnum
    )
    FROM pg_type AS t
    JOIN pg_proc ON pg_proc.oid = t.typsend
    #{join_range}
    WHERE
      pg_proc.proname in #{sql_list(m.send)}
    """
  end

  defp sql_list(list) do
    list = Enum.uniq(list)
    "(" <> Enum.map_join(list, ", ", &("'" <> &1 <> "'")) <> ")"
  end
end
