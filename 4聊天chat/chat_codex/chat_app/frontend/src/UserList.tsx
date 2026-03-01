import { UserSummary } from "./types";

interface UserListProps {
  users: UserSummary[];
}

const UserList = ({ users }: UserListProps) => (
  <div className="card" style={{ flex: "0 0 250px" }}>
    <h3>在线用户</h3>
    <ul>
      {users.map((user) => (
        <li key={user.id}>{user.username}</li>
      ))}
      {users.length === 0 && <li>暂无在线用户</li>}
    </ul>
  </div>
);

export default UserList;
