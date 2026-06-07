export default {
  providers: [
    {
      domain: process.env.CLERK_FRONTEND_API_URL || "https://hopeful-collie-6.clerk.accounts.dev",
      applicationID: "convex",
    },
  ],
};
