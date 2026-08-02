import type { ComponentProps } from "react"
import type { ClerkProvider } from "@clerk/nextjs"
import a from "./auth.module.css"

// @clerk/types isn't a direct dependency — take the shape from the provider
type Appearance = ComponentProps<typeof ClerkProvider>["appearance"]

/**
 * One appearance object for every Clerk surface. Variables cover what Clerk
 * computes internally (focus rings, generated states); the element classes in
 * auth.module.css do the visual work.
 */
export const clerkAppearance: Appearance = {
  variables: {
    colorPrimary: "#28200F", // --deep-brown
    colorBackground: "#F9F6F0", // --warm-white
    colorText: "#28200F",
    colorTextSecondary: "#6E5D45", // --mid-brown
    colorInputBackground: "#F2EDE3", // --linen, never pure white
    colorInputText: "#28200F",
    colorDanger: "#C75B5B",
    borderRadius: "0px",
    fontFamily: "var(--font-sans)",
  },
  elements: {
    cardBox: a.clerkCardBox,
    card: a.clerkCard,
    headerTitle: a.clerkHeaderTitle,
    headerSubtitle: a.clerkHeaderSubtitle,
    socialButtonsBlockButton: a.clerkSocialButton,
    socialButtonsBlockButtonText: a.clerkSocialButtonText,
    dividerLine: a.clerkDividerLine,
    dividerText: a.clerkDividerText,
    formFieldLabel: a.clerkFieldLabel,
    formFieldInput: a.clerkInput,
    formButtonPrimary: a.clerkPrimaryButton,
    footer: a.clerkFooter,
    footerActionText: a.clerkFooterActionText,
    footerActionLink: a.clerkFooterActionLink,
  },
}

/**
 * Clerk builds these strings from the Clerk Dashboard's application name,
 * which still reads "PersonalLM". Overriding here so the product name is
 * correct regardless of the dashboard setting.
 */
export const clerkLocalization = {
  signIn: {
    start: {
      title: "Sign in to Personal OS",
      subtitle: "Your ledger is where you left it.",
    },
  },
  signUp: {
    start: {
      title: "Create your Personal OS",
      subtitle: "Start free — local models, your own keys, no card.",
    },
  },
}
