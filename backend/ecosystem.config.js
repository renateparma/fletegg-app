module.exports = {
  apps: [
    {
      name: 'fletegg-api',
      script: 'server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_memory_restart: '200M',
      env: {
        NODE_ENV: 'production',
        PORT: 5912
      }
    }
  ]
};
