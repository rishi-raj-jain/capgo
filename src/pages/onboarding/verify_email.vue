<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { User } from '@supabase/supabase-js'
import { autoAuth, useSupabase } from '~/services/supabase'
import Spinner from '~/components/Spinner.vue'
import { useMainStore } from '~/stores/main'

const { t } = useI18n()
const supabase = useSupabase()
const route = useRoute()
const router = useRouter()
const main = useMainStore()

const isLoading = ref(true)

const user = ref<User | null>(null)

async function updateDb() {
  // console.log('update db')
  const resSession = await supabase.auth.getSession()!
  let session = resSession.data.session
  if (!session) {
    const logSession = await autoAuth(route)
    if (!logSession)
      return
    if (logSession.session)
      session = logSession.session
    if (logSession.user)
      user.value = logSession.user
  }
  else {
    // console.log('session user', session?.user)
    user.value = session.user
  }
  if (!user.value?.id)
    return

  const { error } = await supabase
    .from('users')
    .insert(
      {
        id: user.value?.id,
        first_name: user.value?.user_metadata.first_name,
        last_name: user.value?.user_metadata.last_name,
        email: user.value?.email || '',
        image_url: '',
      },
    )
  if (error) {
    console.error('updateDb', error)
    setTimeout(() => {
      main.logout()
      setTimeout(() => {
        return router.replace('/login')
      }, 1000)
    }, 1000)
  }
  router.push('/onboarding/activation')

  isLoading.value = false
}

watchEffect(() => {
  if (route.path === '/onboarding/verify_email') {
    setTimeout(async () => {
      await updateDb()
    }, 500)
  }
})
</script>

<template>
  <div>
    <TitleHead :big="true" :title="t('activation-heading')" />
    <div class="flex h-screen">
      <div class="m-auto">
        <Spinner size="w-40 h-40" class="my-auto" />
      </div>
    </div>
  </div>
</template>
