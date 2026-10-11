import { promises as fs } from "node:fs"
import os from "node:os"
import path from "node:path"

const PROVIDER_ID = "9router"
const REQUEST_TIMEOUT_MS = 3000

function getAuthFilePath() {
  const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share")
  const hostClient = process.env.MIMOCODE === "1" ? "mimocode" : "opencode"
  return path.join(dataHome, hostClient, "auth.json")
}

async function readApiKeyFromAuthStore(providerID) {
  try {
    const auths = JSON.parse(await fs.readFile(getAuthFilePath(), "utf8"))
    const entry = auths?.[providerID]
    return entry?.type === "api" && typeof entry.key === "string" && entry.key.trim().length > 0
      ? entry.key.trim()
      : undefined
  } catch {
    return undefined
  }
}

function buildVariants(rawModel) {
  const tiers = rawModel?.capabilities?.effort_tiers
  if (!Array.isArray(tiers)) {
    return undefined
  }

  const variants = {}
  for (const tier of tiers) {
    if (typeof tier !== "string") {
      continue
    }

    const value = tier.trim()
    if (value.length === 0) {
      continue
    }

    variants[value] = { reasoningEffort: value }
  }

  return Object.keys(variants).length > 0 ? variants : undefined
}

export const NineRouterVariants = async () => ({
  config: async (config) => {
    try {
      const provider = config?.provider?.[PROVIDER_ID]
      if (!provider || typeof provider !== "object") {
        return
      }

      const baseURL = provider.options?.baseURL
      if (typeof baseURL !== "string" || baseURL.trim().length === 0) {
        return
      }

      if (!provider.models || typeof provider.models !== "object") {
        return
      }

      const configuredApiKey = provider.options?.apiKey
      const apiKey =
        typeof configuredApiKey === "string" && configuredApiKey.trim().length > 0
          ? configuredApiKey.trim()
          : await readApiKeyFromAuthStore(PROVIDER_ID)

      const response = await fetch(`${baseURL.replace(/\/+$/, "")}/models`, {
        headers: apiKey ? { Authorization: `Bearer ${apiKey}` } : {},
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      })

      if (!response.ok) {
        return
      }

      const payload = await response.json()
      if (!Array.isArray(payload?.data)) {
        return
      }

      for (const rawModel of payload.data) {
        const modelID = rawModel?.id
        if (typeof modelID !== "string") {
          continue
        }

        const model = provider.models[modelID]
        if (!model || typeof model !== "object") {
          continue
        }

        const variants = buildVariants(rawModel)
        if (!variants) {
          continue
        }

        // Fetched variants come first so explicitly configured variants still win.
        model.variants = { ...variants, ...(model.variants ?? {}) }
      }
    } catch {
      // The gateway may be unreachable; discovery failure must never block startup.
    }
  },
})
