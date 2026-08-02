/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as business from "../business.js";
import type * as datascience from "../datascience.js";
import type * as health_connections from "../health/connections.js";
import type * as health_metrics from "../health/metrics.js";
import type * as health_providers from "../health/providers.js";
import type * as health_resolve from "../health/resolve.js";
import type * as health_samples from "../health/samples.js";
import type * as marketing from "../marketing.js";
import type * as wellbeing from "../wellbeing.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  business: typeof business;
  datascience: typeof datascience;
  "health/connections": typeof health_connections;
  "health/metrics": typeof health_metrics;
  "health/providers": typeof health_providers;
  "health/resolve": typeof health_resolve;
  "health/samples": typeof health_samples;
  marketing: typeof marketing;
  wellbeing: typeof wellbeing;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
