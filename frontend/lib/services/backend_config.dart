const String fastApiBaseUrl = String.fromEnvironment(
  'FASTAPI_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

const String flaskStreamingBaseUrl = String.fromEnvironment(
  'FLASK_STREAMING_BASE_URL',
  defaultValue: 'http://127.0.0.1:5001',
);

const String reportApiKey = String.fromEnvironment(
  'REPORT_API_KEY',
  defaultValue: 'pcd-secret',
);
