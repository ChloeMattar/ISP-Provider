// Generic table: give it the columns to show and the rows from the API.
//   columns = [{ key: "FullName", label: "Name", format: optionalFunction }]
//   actions = optional function (row) => buttons for that row
export default function DataTable({ columns, rows, actions }) {
  if (rows.length === 0) {
    return <p className="empty">No rows.</p>;
  }

  return (
    <table>
      <thead>
        <tr>
          {columns.map((column) => (
            <th key={column.key}>{column.label}</th>
          ))}
          {actions && <th></th>}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, index) => (
          <tr key={index}>
            {columns.map((column) => (
              <td key={column.key}>
                {column.format ? column.format(row[column.key], row) : row[column.key]}
              </td>
            ))}
            {actions && <td className="actions">{actions(row)}</td>}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
