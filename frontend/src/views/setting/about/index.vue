<template>
    <div>
        <LayoutContent v-loading="loading" :title="$t('setting.about')" :divider="true">
            <template #main>
                <div style="text-align: center; margin-top: 20px">
                    <div style="justify-self: center" class="logo">
                        <img
                            v-if="globalStore.themeConfig.logo && !logoLoadFailed"
                            style="width: 80px"
                            :src="`/api/v2/images/logo?t=${Date.now()}`"
                            @error="logoLoadFailed = true"
                            alt=""
                        />
                        <PrimaryLogo v-else />
                    </div>
                    <h3 class="description">{{ globalStore.themeConfig.title || $t('setting.description') }}</h3>
                    <!-- hide upgrade/docs/community links in private fork -->
                </div>
            </template>
        </LayoutContent>
    </div>
</template>

<script lang="ts" setup>
import { getSystemAvailable } from '@/api/modules/setting';
import { onMounted, ref } from 'vue';
import { GlobalStore } from '@/store';
import PrimaryLogo from '@/assets/images/1panel-logo.svg?component';
import { storeToRefs } from 'pinia';
const globalStore = GlobalStore();
const { docsUrl } = storeToRefs(globalStore);
const loading = ref();
const logoLoadFailed = ref(false);

const toDoc = () => {
    window.open(docsUrl.value, '_blank', 'noopener,noreferrer');
};
const toGithub = () => {
    window.open('https://github.com/1Panel-dev/1Panel', '_blank', 'noopener,noreferrer');
};
const toIssue = () => {
    window.open('https://github.com/1Panel-dev/1Panel/issues', '_blank', 'noopener,noreferrer');
};
const toGithubStar = () => {
    window.open('https://github.com/1Panel-dev/1Panel', '_blank', 'noopener,noreferrer');
};

onMounted(() => {
    getSystemAvailable();
});
</script>

<style lang="scss" scoped>
.system-link {
    margin-left: 15px;

    .svg-icon {
        font-size: 7px;
    }
    span {
        line-height: 20px;
        font-weight: 400;
    }
}
.description {
    color: var(--el-text-color-regular);
}
.logo {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 55px;
    img {
        object-fit: contain;
        width: 95%;
        height: 45px;
    }
}
.upgrade {
    all: initial;
}
</style>
