<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed, ref, watch, watchEffect } from 'vue'
import { useRoute } from 'vue-router'
import { Capacitor } from '@capacitor/core'
import { storeToRefs } from 'pinia'
import { loadFull } from 'tsparticles'
import { tsParticles } from '@tsparticles/engine'
import { particlesOptions } from './particles.ts'
import { openCheckout } from '~/services/stripe'
import { useMainStore } from '~/stores/main'
import { getCurrentPlanNameOrg, getPlanUsagePercent } from '~/services/supabase'
import { useLogSnag } from '~/services/logsnag'
import { openMessenger } from '~/services/chatwoot'
import type { Database } from '~/types/supabase.types'
import type { Stat } from '~/components/comp_def'
import { useOrganizationStore } from '~/stores/organization'
import type { ArrayElement } from '~/services/types'
import VueParticles from '~/components/VueParticles.vue'

function openSupport() {
  openMessenger()
}

const { t } = useI18n()
const mainStore = useMainStore()

const displayStore = useDisplayStore()
onBeforeMount(async () => {
  console.log('tsParticles mounted')
  tsParticles.init()
  await loadFull(tsParticles)
})

interface PlansOrgData {
  stats: {
    mau: number
    storage: number
    bandwidth: number
  }
  planSuggest: string
  planCurrrent: string
  planPercent: number
  detailPlanUsage: ArrayElement<Database['public']['Functions']['get_plan_usage_percent_detailed']['Returns']>
  paying: boolean
  trialDaysLeft: number
}

function defaultPlanOrgData(): PlansOrgData {
  return {
    stats: {
      mau: 0,
      storage: 0,
      bandwidth: 0,
    },
    planCurrrent: '',
    planPercent: -1,
    planSuggest: '',
    paying: false,
    trialDaysLeft: 0,
    detailPlanUsage: {
      total_percent: 0,
      mau_percent: 0,
      bandwidth_percent: 0,
      storage_percent: 0,
    },
  }
}

const orgsHashmap = ref(new Map<string, PlansOrgData>())

const snag = useLogSnag()
// const isUsageLoading = ref(false)
const initialLoad = ref(false)
const thankYouPage = ref(false)
const isSubscribeLoading = ref<Array<boolean>>([])
const segmentVal = ref<'m' | 'y'>('y')
const isYearly = computed(() => segmentVal.value === 'y')
const route = useRoute()
const router = useRouter()
const main = useMainStore()
const organizationStore = useOrganizationStore()
const isMobile = Capacitor.isNativePlatform()

const { currentOrganization } = storeToRefs(organizationStore)

function planFeatures(plan: Database['public']['Tables']['plans']['Row']) {
  const features = [
  `${plan.mau.toLocaleString()} ${t('mau')}`,
  `${plan.storage.toLocaleString()} ${t('plan-storage')}`,
  `${plan.bandwidth.toLocaleString()} ${t('plan-bandwidth')}`,
  ]
  if (plan.name.toLowerCase().includes('as you go')) {
    if (plan.mau_unit)
      features[0] += ` included, then $${plan.mau_unit}/user`

    if (plan.storage_unit)
      features[1] += ` included, then $${plan.storage_unit} per GB`

    if (plan.bandwidth_unit)
      features[2] += ` included, then $${plan.bandwidth_unit} per GB`

    features.push('API Access')
    features.push('Dedicated support')
    features.push('Custom Domain')
  }
  return features.filter(Boolean)
}

function convertKey(key: string) {
  const keySplit = key.split('.')
  if (keySplit.length === 3)
    return `plan-${keySplit[1]}`
  return key
}

const currentData = computed(() => orgsHashmap.value.get(currentOrganization.value?.gid ?? ''))

const currentPlanSuggest = computed(() => mainStore.plans.find(plan => plan.name === currentData.value?.planSuggest))
const currentPlan = computed(() => mainStore.plans.find(plan => plan.name === currentData.value?.planCurrrent))
const isTrial = computed(() => currentOrganization?.value ? (!currentOrganization?.value.paying && (currentOrganization?.value.trial_left ?? 0) > 0) : false)

async function openChangePlan(plan: Database['public']['Tables']['plans']['Row'], index: number) {
  // get the current url
  isSubscribeLoading.value[index] = true
  if (plan.stripe_id)
    await openCheckout(plan.stripe_id, `${window.location.href}?success=1`, `${window.location.href}?cancel=1`, plan.price_y !== plan.price_m ? isYearly.value : false, currentOrganization?.value?.gid ?? '')
  isSubscribeLoading.value[index] = false
}

function getPrice(plan: Database['public']['Tables']['plans']['Row'], t: 'm' | 'y'): number {
  if (t === 'm' || plan.price_y === plan.price_m) {
    return plan.price_m
  }
  else {
    const p = plan.price_y
    return +(p / 12).toFixed(0)
  }
}

function isYearlyPlan(plan: Database['public']['Tables']['plans']['Row'], t: 'm' | 'y'): boolean {
  return t === 'y'
}

// function getSale(plan: Database['public']['Tables']['plans']['Row']): string {
//   return `- ${100 - Math.round(plan.price_y * 100 / (plan.price_m * 12))} %`
// }

async function loadData(initial: boolean) {
  if (!initialLoad.value && !initial)
    return

  await organizationStore.awaitInitialLoad()

  const orgToLoad = currentOrganization.value
  const orgId = orgToLoad?.gid
  if (!orgId)
    throw new Error('Cannot get current org id')

  if (orgsHashmap.value.has(orgId))
    return

  const data = defaultPlanOrgData()

  await Promise.all([
    getCurrentPlanNameOrg(orgId).then((res) => {
      data.planCurrrent = res
      // updateData()
    }),
    getPlanUsagePercent(orgId).then((res) => {
      // console.log('getPlanUsagePercent', res)
      data.planPercent = res.total_percent
      data.detailPlanUsage = res
      // updateData()
    }).catch(err => console.log(err)),
    // isPayingOrg(orgId).then(res => {
    //   data.paying = res
    // })
  ])
  data.stats = main.totalStats
  data.planSuggest = main.bestPlan

  data.stats = main.totalStats
  data.planSuggest = main.bestPlan
  data.paying = orgToLoad.paying
  data.trialDaysLeft = orgToLoad.trial_left

  orgsHashmap.value.set(orgId, data)
  initialLoad.value = true
}

// watch(
//   () => plans.value,
//   (myPlan, prevMyPlan) => {
//     if (myPlan && !prevMyPlan) {
//       loadData(true)
//       // reGenerate annotations
//       isUsageLoading.value = true
//     }
//     else if (prevMyPlan && !myPlan) {
//       isUsageLoading.value = true
//     }
//   },
// )

watch(currentOrganization, async (newOrg, prevOrg) => {
  // isSubscribeLoading.value.fill(true, 0, plans.value.length)

  if (!organizationStore.hasPermisisonsInRole(await organizationStore.getCurrentRole(newOrg?.created_by ?? ''), ['super_admin'])) {
    if (!initialLoad.value) {
      const orgsMap = organizationStore.getAllOrgs()
      const newOrg = [...orgsMap]
        .map(([_, a]) => a)
        .filter(org => org.role.includes('super_admin'))
        .sort((a, b) => b.app_count - a.app_count)[0]

      if (newOrg) {
        organizationStore.setCurrentOrganization(newOrg.gid)
        return
      }
    }

    displayStore.dialogOption = {
      header: t('cannot-view-plans'),
      message: `${t('plans-super-only')}`,
      buttons: [
        {
          text: t('ok'),
        },
      ],
    }
    displayStore.showDialog = true
    await displayStore.onDialogDismiss()
    if (!prevOrg)
      router.push('/app/home')
    else
      organizationStore.setCurrentOrganization(prevOrg.gid)
  }

  await loadData(false)

  // isSubscribeLoading.value.fill(false, 0, plans.value.length)
})

watchEffect(async () => {
  if (route.path === '/dashboard/settings/plans') {
    // if session_id is in url params show modal success plan setup
    if (route.query.session_id) {
      // toast.success(t('usage-success'))
      thankYouPage.value = true
    }
    else if (main.user?.id) {
      if (route.query.oid && typeof route.query.oid === 'string') {
        await organizationStore.awaitInitialLoad()
        organizationStore.setCurrentOrganization(route.query.oid)
      }

      loadData(true)
      snag.track({
        channel: 'usage',
        event: 'User visit',
        icon: '💳',
        user_id: currentOrganization.value?.gid,
        notify: false,
      }).catch()
    }
  }
})
function isDisabled(plan: Database['public']['Tables']['plans']['Row']) {
  return (currentPlan.value?.name === plan.name && currentOrganization.value?.paying) || isMobile
}

const hightLights = computed<Stat[]>(() => ([
  {
    label: (!!currentData.value?.paying || (currentData.value?.trialDaysLeft ?? 0) > 0 || isTrial.value) ? t('Current') : t('failed'),
    value: currentPlan.value?.name,
  },
  {
    label: t('usage'),
    value: (currentData.value && currentData.value.planPercent !== undefined && currentData.value.planPercent > -1) ? `${currentData.value?.planPercent.toLocaleString()}%` : undefined,
    informationIcon: () => {
      if (!currentData.value?.detailPlanUsage.mau_percent && !currentData.value?.detailPlanUsage.storage_percent && !currentData.value?.detailPlanUsage.bandwidth_percent)
        return

      displayStore.dialogOption = {
        header: t('detailed-usage-plan'),
        message: `${t('your-ussage')}\n${t('mau-usage')}${currentData.value?.detailPlanUsage.mau_percent}%\n${t('bandwith-usage')}${currentData.value?.detailPlanUsage.bandwidth_percent}%\n${t('storage-usage')}${currentData.value?.detailPlanUsage.storage_percent}%`,
        buttons: [
          {
            text: t('ok'),
          },
        ],
      }
      displayStore.showDialog = true
    },
  },
  {
    label: t('best-plan'),
    value: currentPlanSuggest.value?.name,
  },
]))
</script>

<template>
  <div v-if="!thankYouPage" class="h-full bg-white max-h-fit dark:bg-gray-800">
    <div class="px-4 pt-6 mx-auto max-w-7xl lg:px-8 sm:px-6">
      <div class="sm:align-center sm:flex sm:flex-col">
        <h1 class="text-5xl font-extrabold text-gray-900 sm:text-center dark:text-white">
          {{ t('plan-pricing-plans') }}
        </h1>
        <p class="mt-5 text-xl text-gray-700 sm:text-center dark:text-white">
          {{ t('plan-desc') }}<br>
        </p>
      </div>
      <section class="px-8 pt-4 sm:px-0">
        <BlurBg :mini="true">
          <template #default>
            <StatsBar :mini="true" :stats="hightLights" />
          </template>
        </BlurBg>
      </section>
      <div class="flex items-center justify-center mt-8 space-x-6 sm:mt-12">
        <div class="flex items-center" @click="segmentVal = 'm'">
          <input
            id="monthly" type="radio" name="pricing-plans"
            class="w-4 h-4 text-blue-300 border border-gray-200 dark:text-blue-600 focus:outline-none focus:ring-1 focus:ring-blue-600"
            :checked="segmentVal === 'm'"
          >
          <label for="monthly" class="block ml-3 text-sm font-medium sm:text-base">
            {{ t('monthly-plan') }}
          </label>
        </div>

        <div class="flex items-center" @click="segmentVal = 'y'">
          <input
            id="yearly" type="radio" name="pricing-plans"
            class="w-4 h-4 text-blue-300 border border-gray-200 dark:text-blue-600 focus:outline-none focus:ring-1 focus:ring-blue-600"
            :checked="segmentVal === 'y'"
          >
          <label for="yearly" class="block ml-3 text-sm font-medium sm:text-base">
            {{ t('yearly') }}
          </label>
          <span class="ml-1 text-sm font-medium text-blue-600">
            ({{ t('save') }} 20%)
          </span>
        </div>
      </div>
      <div class="mt-12 space-y-12 sm:grid sm:grid-cols-2 xl:grid-cols-4 lg:mx-auto xl:mx-0 lg:max-w-4xl xl:max-w-none sm:gap-6 sm:space-y-0">
        <div v-for="(p, index) in mainStore.plans" :key="p.price_m" class="relative mt-12 border border-gray-200 divide-y divide-gray-200 rounded-lg shadow-sm md:mt-0" :class="p.name === currentPlan?.name ? 'border-4 border-muted-blue-600' : ''">
          <div v-if="currentPlanSuggest?.name === p.name && currentPlan?.name !== p.name" class="absolute top-0 right-0 flex items-start -mt-8">
            <svg
              class="w-auto h-16 text-blue-600 dark:text-red-500" viewBox="0 0 83 64" fill="currentColor"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M4.27758 62.7565C4.52847 63.5461 5.37189 63.9827 6.16141 63.7318L19.0274 59.6434C19.817 59.3925 20.2536 58.5491 20.0027 57.7595C19.7518 56.97 18.9084 56.5334 18.1189 56.7842L6.68242 60.4184L3.04824 48.982C2.79735 48.1924 1.95394 47.7558 1.16441 48.0067C0.374889 48.2576 -0.0617613 49.101 0.189127 49.8905L4.27758 62.7565ZM13.4871 47.8215L12.229 47.0047L13.4871 47.8215ZM39.0978 20.5925L38.1792 19.4067L39.0978 20.5925ZM7.03921 62.9919C8.03518 61.0681 13.1417 51.1083 14.7453 48.6383L12.229 47.0047C10.5197 49.6376 5.30689 59.8127 4.37507 61.6126L7.03921 62.9919ZM14.7453 48.6383C22.0755 37.3475 29.8244 29.6738 40.0164 21.7784L38.1792 19.4067C27.7862 27.4579 19.7827 35.3698 12.229 47.0047L14.7453 48.6383ZM40.0164 21.7784C52.6582 11.9851 67.634 7.57932 82.2576 3.44342L81.4412 0.556653C66.8756 4.67614 51.3456 9.20709 38.1792 19.4067L40.0164 21.7784Z"
              />
            </svg>
            <span class="ml-2 -mt-2 text-sm font-semibold text-blue-600 dark:text-red-500">
              {{ t('recommended') }}
            </span>
          </div>
          <div class="p-6 border-none">
            <div class="flex flex-row">
              <h2 class="text-lg font-medium leading-6 text-gray-900 dark:text-white">
                {{ p.name }}
              </h2>
              <h2 v-if="isTrial && currentPlanSuggest?.name === p.name" class="px-2 ml-auto text-white bg-blue-600 rounded-full dark:text-white">
                {{ t('free-trial') }}
              </h2>
            </div>
            <p class="mt-4 text-sm text-gray-500 dark:text-gray-100">
              {{ t(convertKey(p.description)) }}
            </p>
            <p class="mt-8">
              <span class="text-4xl font-extrabold text-gray-900 dark:text-white">
                ${{ getPrice(p, segmentVal) }}
              </span>
              <span class="text-base font-medium text-gray-500 dark:text-gray-100">/{{ t('mo') }}</span>
            </p>
            <button
              :class="{ 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-700': currentPlanSuggest?.name === p.name, 'bg-black dark:bg-white dark:text-black hover:bg-gray-500 focus:ring-gray-500': currentPlanSuggest?.name !== p.name, 'cursor-not-allowed bg-gray-500 dark:bg-gray-400': currentPlan?.name === p.name && currentData?.paying }"
              class="block w-full py-2 mt-8 text-sm font-semibold text-center text-white border border-gray-800 rounded-md"
              :disabled="isDisabled(p)" @click="openChangePlan(p, index)"
            >
              <svg v-if="isSubscribeLoading[index]" class="inline-block w-5 h-5 mr-3 -ml-1 text-white align-middle dark:text-gray-900 animate-spin" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
              </svg>
              {{ isMobile ? t('check-on-web') : (currentPlan?.name === p.name && currentData?.paying ? t('Current') : t('plan-upgrade')) }}
            </button>
            <p v-if="isYearlyPlan(p, segmentVal)" class="mt-8">
              <span class="text-gray-900 dark:text-white">{{ p.price_m !== p.price_y ? t('billed-annually-at') : t('billed-monthly-at') }} ${{ p.price_y }}</span>
            </p>
          </div>
          <div class="px-6 pt-6 pb-8">
            <h3 class="text-xs font-medium tracking-wide text-gray-900 uppercase dark:text-white">
              {{ t('plan-whats-included') }}
            </h3>
            <ul role="list" class="mt-6 space-y-4">
              <li v-for="(f, indexx) in planFeatures(p)" :key="indexx" class="flex space-x-3">
                <svg class="flex-shrink-0 w-5 h-5 text-green-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
                <span class="text-sm text-gray-500 dark:text-gray-100">{{ f }}</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
      <div v-if="!isMobile" class="mt-4 text-center">
        <p class="mt-2 text-lg text-gray-700 sm:text-center dark:text-white">
          {{ t('plan-page-warn').replace('%ORG_NAME%', currentOrganization?.name ?? '') }}
          <a class="text-blue-600" href="https://capgo.app/docs/docs/webapp/payment/">{{ t('plan-page-warn-2') }}</a>
          <br>
        </p>
      </div>
      <section v-if="!isMobile" class="py-12 lg:py-20 sm:py-16">
        <div class="px-4 mx-auto max-w-7xl lg:px-8 sm:px-6">
          <div class="max-w-2xl mx-auto text-center">
            <h2 class="text-3xl font-bold text-white-900 font-pj sm:text-4xl xl:text-5xl dark:text-white">
              {{ t('need-more-contact-us') }}
            </h2>
          </div>

          <BlurBg background="">
            <template #default>
              <div class="w-full px-16 py-8 lg:px-16 lg:py-14 sm:px-8 bg-blue-50">
                <div class="w-full md:flex md:items-center lg:space-x-6 md:space-x-4">
                  <div class="grid grid-cols-1 gap-x-12 gap-y-3 sm:grid-cols-2 xl:gap-x-24">
                    <div>
                      <ul class="space-y-3 text-base font-medium text-black font-pj">
                        <li class="flex items-center">
                          <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ t('unlimited-updates') }}
                        </li>

                        <li class="flex items-center">
                          <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ t('bigger-app-size') }}
                        </li>

                        <li class="flex items-center">
                          <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ t('more-version-storage') }}
                        </li>
                      </ul>
                    </div>

                    <div>
                      <ul class="space-y-3 text-base font-medium text-black font-pj">
                        <li class="flex items-center">
                          <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ t('custom-domain') }}
                        </li>

                        <li class="flex items-center">
                          <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ t('special-api-access') }}
                        </li>

                        <li class="flex items-center">
                          <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ t('bulk-upload') }}
                        </li>
                      </ul>
                    </div>
                  </div>

                  <div class="block lg:block md:hidden">
                    <div class="hidden lg:block">
                      <svg class="w-4 h-auto dark:text-gray-600" viewBox="0 0 16 123" fill="none" stroke="currentColor" xmlns="http://www.w3.org/2000/svg">
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 11)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 46)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 81)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 116)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 18)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 53)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 88)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 123)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 25)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 60)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 95)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 32)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 67)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 102)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 39)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 74)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.83205 -0.5547 -0.5547 0.83205 15 109)" />
                      </svg>
                    </div>

                    <div class="block mt-10 md:hidden">
                      <svg class="w-auto h-4 dark:text-gray-600" viewBox="0 0 172 16" fill="none" stroke="currentColor" xmlns="http://www.w3.org/2000/svg">
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 11 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 46 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 81 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 116 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 151 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 18 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 53 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 88 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 123 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 158 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 25 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 60 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 95 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 130 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 165 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 32 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 67 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 102 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 137 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 172 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 39 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 74 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 109 1)" />
                        <line y1="-0.5" x2="18.0278" y2="-0.5" transform="matrix(-0.5547 0.83205 0.83205 0.5547 144 1)" />
                      </svg>
                    </div>
                  </div>

                  <div class="!mx-auto mt-10 md:mt-0">
                    <a
                      href="#"
                      title="Get quote now"
                      class="inline-flex items-center justify-center p-6 mt-5 text-base font-bold text-gray-300 transition-all duration-200 bg-black border font-pj rounded-xl hover:bg-opacity-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-black"
                      role="button"
                      @click="openSupport()"
                    >
                      Get quote now
                    </a>
                  </div>
                </div>
              </div>
            </template>
          </BlurBg>
        </div>
      </section>
    </div>
  </div>
  <div v-else class="relative w-full overflow-hidden ">
    <VueParticles
      id="tsparticles"
      class="absolute z-0 w-full h-full"
      :options="particlesOptions"
    />
    <div class="absolute z-10 right-0 left-0 ml-auto mt-[5vh] text-2xl mr-auto text-center w-fit flex flex-col">
      <img src="/capgo.webp" alt="logo" class="h-[4rem]  w-[4rem] ml-auto mr-auto mb-[4rem]">
      {{ t('thank-you-for-sub') }}
      <span class=" mt-[2.5vh] text-[3.5rem]">🎉</span>
      <router-link class="mt-[40vh]" to="/app/home">
        <span class="text-xl text-blue-600">{{ t('use-capgo') }} 🚀</span>
      </router-link>
    </div>
  </div>
</template>

<route lang="yaml">
meta:
  layout: settings
        </route>
