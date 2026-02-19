#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

static JavaVM *g_vm = NULL;
static jclass g_bridge_class = NULL;
static jmethodID g_handle_call_id = NULL;

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    g_vm = vm;
    return JNI_VERSION_1_6;
}

static int ensure_bridge(JNIEnv *env) {
    if (g_bridge_class != NULL && g_handle_call_id != NULL) return 1;
    g_bridge_class = (*env)->FindClass(env, "com/native_binder/NativeBinderBridge");
    if (!g_bridge_class) return 0;
    g_bridge_class = (*env)->NewGlobalRef(env, g_bridge_class);
    g_handle_call_id = (*env)->GetStaticMethodID(env, g_bridge_class, "handleCall", "([B)[B");
    return g_handle_call_id != NULL;
}

__attribute__((visibility("default")))
uint8_t *native_binder_call(uint8_t *msg, uint32_t len, uint32_t *out_len) {
    *out_len = 0;
    if (!g_vm || !msg) return NULL;

    JNIEnv *env = NULL;
    int attached = 0;
    if ((*g_vm)->GetEnv(g_vm, (void **)&env, JNI_VERSION_1_6) == JNI_EDETACHED) {
        if ((*g_vm)->AttachCurrentThread(g_vm, &env, NULL) != JNI_OK) return NULL;
        attached = 1;
    }

    if (!ensure_bridge(env)) {
        if (attached) (*g_vm)->DetachCurrentThread(g_vm);
        return NULL;
    }

    jbyteArray in_arr = (*env)->NewByteArray(env, (jsize)len);
    if (!in_arr) {
        if (attached) (*g_vm)->DetachCurrentThread(g_vm);
        return NULL;
    }
    (*env)->SetByteArrayRegion(env, in_arr, 0, (jsize)len, (jbyte *)msg);

    jbyteArray out_arr = (jbyteArray)(*env)->CallStaticObjectMethod(env, g_bridge_class, g_handle_call_id, in_arr);
    (*env)->DeleteLocalRef(env, in_arr);

    if ((*env)->ExceptionCheck(env) || !out_arr) {
        if (out_arr) (*env)->DeleteLocalRef(env, out_arr);
        if (attached) (*g_vm)->DetachCurrentThread(g_vm);
        return NULL;
    }

    jsize out_len_jsize = (*env)->GetArrayLength(env, out_arr);
    uint32_t out_len_val = (uint32_t)out_len_jsize;
    uint8_t *out_ptr = NULL;
    if (out_len_val > 0) {
        out_ptr = (uint8_t *)malloc((size_t)out_len_val);
        if (out_ptr) {
            (*env)->GetByteArrayRegion(env, out_arr, 0, out_len_jsize, (jbyte *)out_ptr);
            *out_len = out_len_val;
        }
    } else {
        out_ptr = (uint8_t *)malloc(1);
        if (out_ptr) *out_len = 0;
    }
    (*env)->DeleteLocalRef(env, out_arr);

    if (attached) (*g_vm)->DetachCurrentThread(g_vm);
    return out_ptr;
}

__attribute__((visibility("default")))
void native_binder_free(uint8_t *ptr) {
    if (ptr) free(ptr);
}
