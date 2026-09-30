import { describe, expect, test } from "vitest"
import { storeConfig } from "./lib/appStoreConfig"

/** Which App Store purchases the backend will believe, by deployment setting. */

describe("store config", () => {
  test("defaults to sandbox, which is what TestFlight and App Review use", () => {
    expect(storeConfig({})).toEqual({ environments: ["sandbox"] })
    expect(storeConfig({ APPLE_IAP_ENVIRONMENT: "" })).toEqual({ environments: ["sandbox"] })
    expect(storeConfig({ APPLE_IAP_ENVIRONMENT: " Sandbox " })).toEqual({ environments: ["sandbox"] })
  })

  test("production needs the app's Apple ID, and still accepts App Review's sandbox purchases", () => {
    expect(() => storeConfig({ APPLE_IAP_ENVIRONMENT: "production" })).toThrow("APPLE_APP_ID")
    expect(() => storeConfig({ APPLE_IAP_ENVIRONMENT: "production", APPLE_APP_ID: "abc" }))
      .toThrow("APPLE_APP_ID")
    expect(storeConfig({ APPLE_IAP_ENVIRONMENT: "production", APPLE_APP_ID: "6450000000" })).toEqual({
      environments: ["production", "sandbox"],
      appAppleId: 6450000000,
    })
  })

  test("unsigned Xcode purchases need a second, explicit setting", () => {
    expect(() => storeConfig({ APPLE_IAP_ENVIRONMENT: "xcode" })).toThrow("APPLE_IAP_ALLOW_UNSIGNED")
    expect(storeConfig({ APPLE_IAP_ENVIRONMENT: "xcode", APPLE_IAP_ALLOW_UNSIGNED: "true" }))
      .toEqual({ environments: ["xcode"] })
  })

  test("a typo is an error rather than a guess", () => {
    expect(() => storeConfig({ APPLE_IAP_ENVIRONMENT: "prod" })).toThrow('Unknown APPLE_IAP_ENVIRONMENT "prod"')
  })
})
