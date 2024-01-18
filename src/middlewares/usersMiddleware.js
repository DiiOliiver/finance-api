const validateFieldName = (request, response, next) => {
  const { body } = request;

  if (body.name === undefined) {
    return response.status(400).json({ message: 'The field "name" is required.'});
  }

  if (body.name === '') {
    return response.status(400).json({ message: 'Name cannot be empty.'});
  }

  next();
};

const validateFieldLogin = (request, response, next) => {
  const { body } = request;

  if (body.login === undefined) {
    return response.status(400).json({ message: 'The field "login" is required.'});
  }

  if (body.login === '') {
    return response.status(400).json({ message: 'Login cannot be empty.'});
  }

  next();
};

const validateFieldStatus = (request, response, next) => {
  const { body } = request;

  if (body.status === undefined) {
    return response.status(400).json({ message: 'The field "status" is required.'});
  }

  if (body.status === '') {
    return response.status(400).json({ message: 'Status cannot be empty.'});
  }

  next();
};

module.exports = {
  validateFieldName,
  validateFieldLogin,
  validateFieldStatus
};