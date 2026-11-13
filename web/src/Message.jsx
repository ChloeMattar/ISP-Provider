// Green box for success, red box for an error coming back from the API.
export default function Message({ message }) {
  if (!message) return null;
  return <div className={message.error ? "message error" : "message ok"}>{message.text}</div>;
}
