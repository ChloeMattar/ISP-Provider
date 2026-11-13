import { useState } from "react";
import Customers from "./pages/Customers";
import Plans from "./pages/Plans";
import Subscriptions from "./pages/Subscriptions";
import Billing from "./pages/Billing";
import Usage from "./pages/Usage";

const pages = {
  Customers: Customers,
  Plans: Plans,
  Subscriptions: Subscriptions,
  Billing: Billing,
  Usage: Usage,
};

export default function App() {
  const [current, setCurrent] = useState("Customers");
  const Page = pages[current];

  return (
    <div className="app">
      <header>
        <h1>ISP Management</h1>
        <nav>
          {Object.keys(pages).map((name) => (
            <button
              key={name}
              className={name === current ? "tab active" : "tab"}
              onClick={() => setCurrent(name)}
            >
              {name}
            </button>
          ))}
        </nav>
      </header>
      <main>
        <Page />
      </main>
    </div>
  );
}
