const express = require('express');
const usersMiddleware = require('./middlewares/usersMiddleware');
const userController = require('./controllers/userController');

const router = express.Router();

router.get('/users', userController.getAll);
router.post('/users',
  usersMiddleware.validateFieldName,
  usersMiddleware.validateFieldLogin,
  userController.createUser
);
router.delete('/users/:id', userController.deleteUser);
router.put(
  '/users/:id',
  usersMiddleware.validateFieldName,
  usersMiddleware.validateFieldLogin,
  usersMiddleware.validateFieldStatus,
  userController.updateUser
);

module.exports = router;