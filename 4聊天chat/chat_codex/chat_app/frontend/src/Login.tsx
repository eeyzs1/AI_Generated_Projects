import { FormEvent, useState } from "react";

interface LoginProps {
  onSubmit: (values: { username: string; password: string }) => Promise<void>;
  switchToRegister: () => void;
  isLoading?: boolean;
}

const Login = ({ onSubmit, switchToRegister, isLoading }: LoginProps) => {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    await onSubmit({ username, password });
  };
  return (
    <div className="card">
      <h2>登录</h2>
      <form onSubmit={handleSubmit}>
        <label>
          用户名
          <input value={username} onChange={(e) => setUsername(e.target.value)} required />
        </label>
        <label>
          密码
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        <button type="submit" disabled={isLoading}>
          {isLoading ? "登录中..." : "登录"}
        </button>
      </form>
      <p>
        还没有账户？ <button onClick={switchToRegister}>立即注册</button>
      </p>
    </div>
  );
};

export default Login;
