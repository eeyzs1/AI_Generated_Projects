import { FormEvent, useState } from "react";

interface RegisterProps {
  onSubmit: (values: { username: string; email: string; password: string }) => Promise<void>;
  switchToLogin: () => void;
  isLoading?: boolean;
}

const Register = ({ onSubmit, switchToLogin, isLoading }: RegisterProps) => {
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    await onSubmit({ username, email, password });
  };

  return (
    <div className="card">
      <h2>注册</h2>
      <form onSubmit={handleSubmit}>
        <label>
          用户名
          <input value={username} onChange={(e) => setUsername(e.target.value)} required />
        </label>
        <label>
          邮箱
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </label>
        <label>
          密码
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        <button type="submit" disabled={isLoading}>
          {isLoading ? "注册中..." : "注册"}
        </button>
      </form>
      <p>
        已有账号？ <button onClick={switchToLogin}>返回登录</button>
      </p>
    </div>
  );
};

export default Register;
