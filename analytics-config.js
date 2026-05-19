// Public PostHog configuration. The project API key is safe to expose in browser apps.
// Fill these in from PostHog Project Settings -> Project API Key and API host.
window.POSTHOG_CONFIG = {
  apiKey: 'phc_wydxN4gPoUu8xgUoSmhoh82JvnaZr9t8BBMZjLA2jeqk',
  apiHost: 'https://eu.i.posthog.com',
  defaults: '2026-01-30',
  sessionReplay: true,
};

// Shared token for the server-side meal analysis function.
// Set MEAL_TRACKER_TOKEN to this value in your Netlify environment variables.
window.APP_CONFIG = {
  serverToken: 'f60c9972646d37fe29b95d95806f103c551799183c90d388',
};
