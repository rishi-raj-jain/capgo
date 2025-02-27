<script setup lang="ts">
import { Modal } from 'flowbite'
import { onMounted, ref, watch } from 'vue'
import type { ModalInterface, ModalOptions } from 'flowbite'
import DOMPurify from 'dompurify'
import { FormKit } from '@formkit/vue'
import type { ActionSheetOptionButton } from '~/stores/display'
import { useDisplayStore } from '~/stores/display'

/*
* $targetEl: required
* options: optional
*/
const displayStore = useDisplayStore()
function close(item?: ActionSheetOptionButton, i?: any) {
  console.log(i)
  if (displayStore?.dialogOption)
    displayStore.dialogOption.preventAccidentalClose = false
  if (!item?.preventClose)
    displayStore.showDialog = false
  if (item) {
    displayStore.lastButtonRole = item.id ?? ''
    if (item.role === 'cancel')
      displayStore.dialogCanceled = true

    else
      displayStore.dialogCanceled = false

    item?.handler && item.handler()
  }
}

const modalElement = ref(null)

function displayText(text?: string) {
  if (!text)
    return ''
  const sanitize = DOMPurify.sanitize(text.replace(/\n/g, '<br/>'))
  return sanitize
}

function submit(form: { text: string }) {
  displayStore.dialogInputText = form.text
}

onMounted(() => {
  const modalOptions: ModalOptions = {
    placement: 'center',
    backdrop: 'dynamic',
    backdropClasses: 'bg-gray-900 bg-opacity-50 dark:bg-opacity-80 fixed inset-0 z-40',
    closable: true,
    onHide: () => {
      console.log('modal is hidden')
      displayStore.showDialog = false
    },
    onShow: () => {
      console.log('modal is shown')
    },
    onToggle: () => {
      console.log('modal has been toggled')
    },
  }

  let modal: ModalInterface = new Modal(modalElement.value, modalOptions)

  // watch for changes
  watch(() => displayStore.showDialog, (val) => {
    if (!val)
      displayStore.dialogInputText = ''
    const closable = !displayStore.dialogOption?.preventAccidentalClose
    if (modalOptions.closable !== closable) {
      modalOptions.closable = closable
      modal.destroy()
      modal = new Modal(modalElement.value, modalOptions)
    }

    if (val && modal) {
      displayStore.dialogCanceled = true
      modal.show()
    }
    else if (modal) {
      if (displayStore?.dialogOption)
        displayStore.dialogOption.preventAccidentalClose = false
      modal.hide()
    }
  })
})
</script>

<template>
  <div
    ref="modalElement" tabindex="-1"
    aria-hidden="true"
    class="fixed left-0 right-0 top-0 z-50 hidden h-[calc(100%-1rem)] w-full overflow-x-hidden overflow-y-auto p-4 md:inset-0 md:h-full"
  >
    <div id="popout" class="relative w-full h-auto" :class="displayStore.dialogOption?.size ?? 'max-w-2xl'">
      <!-- Modal content -->
      <div class="relative bg-white rounded-lg shadow dark:bg-gray-700">
        <!-- Modal header -->
        <div class="flex items-start justify-between p-4 border-b rounded-t dark:border-gray-600">
          <h3 class="text-xl font-semibold text-gray-900 dark:text-white" :class="displayStore.dialogOption?.headerStyle">
            {{ displayStore.dialogOption?.header }}
          </h3>
          <button type="button" class="ml-auto inline-flex items-center rounded-lg bg-transparent p-1.5 text-sm text-gray-400 hover:bg-gray-200 hover:text-gray-900 dark:hover:bg-gray-600 dark:hover:text-white" @click="close({ role: 'cancel' } as ActionSheetOptionButton)">
            <svg aria-hidden="true" class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" /></svg>
            <span class="sr-only">Close modal</span>
          </button>
        </div>
        <!-- Modal body -->
        <div class="p-6 space-y-6">
          <p class="text-base leading-relaxed prose text-gray-500 break-words dark:text-gray-400" :class="displayStore.dialogOption?.textStyle" v-html="displayText(displayStore.dialogOption?.message)" />
          <img v-if="displayStore.dialogOption?.image" :src="displayStore.dialogOption?.image" class="ml-auto mr-auto">
          <div v-if="displayStore.dialogOption?.input" class="w-full">
            <FormKit id="dialog-input" type="form" :actions="false" @submit="submit">
              <FormKit
                v-model="displayStore.dialogInputText"
                type="text"
                name="text"
                enterkeyhint="next"
                validation="required:trim"
                :classes="{
                  input: 'text-center',
                  message: 'text-center',
                }"
              />
            </FormKit>
          </div>
        </div>
        <!-- Modal footer -->
        <div
          class="flex items-center p-6 border-t border-gray-200 rounded-b dark:border-gray-600"
          :class="{
            'space-x-2': !displayStore.dialogOption?.buttonCenter,
          }"
        >
          <button
            v-for="(item, i) in displayStore.dialogOption?.buttons"
            :key="i"
            :class="{
              'text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800': item.role !== 'cancel',
              'text-gray-500 bg-white hover:bg-gray-100 focus:ring-4 focus:outline-none focus:ring-blue-300 rounded-lg border border-gray-200 text-sm font-medium px-5 py-2.5 hover:text-gray-900 focus:z-10 dark:bg-gray-700 dark:text-gray-300 dark:border-gray-500 dark:hover:text-white dark:hover:bg-gray-600 dark:focus:ring-gray-600': item.role === 'cancel',
              'ml-auto mr-2': displayStore.dialogOption?.buttonCenter && i === 0 && (displayStore.dialogOption?.buttons?.length ?? 0) > 1,
              'mr-auto ml-2': displayStore.dialogOption?.buttonCenter && i === (displayStore.dialogOption?.buttons?.length ?? 0) - 1 && (displayStore.dialogOption?.buttons?.length ?? 0) > 1,
              'mx-auto': displayStore.dialogOption?.buttonCenter && (displayStore.dialogOption?.buttons?.length ?? 0) === 1,
            }"
            class="rounded-lg bg-blue-700 px-5 py-2.5 text-center text-sm font-mediumtext-white dark:bg-blue-600 hover:bg-blue-800 focus:outline-none focus:ring-4 focus:ring-blue-300 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
            @click="close(item, i)"
          >
            {{ item.text }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
