const connection = require('./connection');

const getAll = async () => {
  const query = 'SELECT * FROM users';
  const [users] = await connection.execute(query);
  return users;
};

const createUser = async (user) => {
  const { name, login, password } = user;
  const query = 'INSERT INTO users(name, login, password, status, created_at) values (?, ?, ?, ?, ?)';
  const dateUtc = new Date(Date.now());
  const [createUser] = await connection.execute(query, [name, login, password, 2, dateUtc]);
  return {
    insertId: createUser.insertId
  };
};

const deleteUser = async (id) => {
  const query = 'DELETE FROM users where id = ?';
  const [removeUser] = await connection.execute(query, [id]);
  return removeUser;
};

const updateUser = async (id, user) => {
  const { name, login, password, status } = user;
  const query = 'UPDATE users SET name = ?, login = ?, password = ?, status = ?, updated_at = ? where id = ?';
  const dateUtc = new Date(Date.now());
  const [updateUser] = await connection.execute(query, [name, login, password, status, dateUtc, id]);
  return updateUser;
};

module.exports = {
  getAll,
  createUser,
  deleteUser,
  updateUser
};