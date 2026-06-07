#include <jni.h>
  #include <string>
  #include <cstdlib>
  #include <pthread.h>
  #include <unistd.h>
  #include <android/log.h>

  #include "node.h"
  #include "rn-bridge.h"

  JNIEnv* cacheEnvPointer = NULL;

  extern "C"
  JNIEXPORT void JNICALL
  Java_com_aivos_wabot_app_BotEngine_sendMessageToNodeChannel(
          JNIEnv *env, jobject, jstring channelName, jstring msg) {
      const char* nativeChannel = env->GetStringUTFChars(channelName, 0);
      const char* nativeMsg = env->GetStringUTFChars(msg, 0);
      rn_bridge_notify(nativeChannel, nativeMsg);
      env->ReleaseStringUTFChars(channelName, nativeChannel);
      env->ReleaseStringUTFChars(msg, nativeMsg);
  }

  extern "C" int callintoNode(int argc, char *argv[]) {
      // ── FIX SIGTRAP — Android ARM64 (Samsung Galaxy + Android 15) ────────
      //
      // Problème : dans nodejs-mobile 18.20.4, la libnode.so ARM64 est compilée
      // avec V8_TRAP_HANDLER_SUPPORTED=false. Pourtant, Node.js appelle
      // v8::internal::trap_handler::EnableTrapHandler() pendant l'initialisation
      // de la plateforme V8, AVANT que les args CLI (--no-wasm-trap-handler)
      // soient parsés. Le CHECK(false) interne génère une instruction BRK →
      // signal 5 SIGTRAP → crash fatal du process.
      //
      // Solution : appeler V8::SetFlagsFromString() AVANT node::Start() pour
      // que le flag soit actif avant toute initialisation V8. Ajouter aussi
      // NODE_OPTIONS comme filet de sécurité.
      //
      v8::V8::SetFlagsFromString("--no-wasm-trap-handler");
      setenv("NODE_OPTIONS", "--no-wasm-trap-handler --no-experimental-fetch", 1);

      return node::Start(argc, argv);
  }

  #if defined(__arm__)
      #define CURRENT_ABI_NAME "armeabi-v7a"
  #elif defined(__aarch64__)
      #define CURRENT_ABI_NAME "arm64-v8a"
  #elif defined(__i386__)
      #define CURRENT_ABI_NAME "x86"
  #elif defined(__x86_64__)
      #define CURRENT_ABI_NAME "x86_64"
  #else
      #error "Unknown ABI."
  #endif

  extern "C"
  JNIEXPORT jstring JNICALL
  Java_com_aivos_wabot_app_BotEngine_getCurrentABIName(JNIEnv *env, jobject) {
      return env->NewStringUTF(CURRENT_ABI_NAME);
  }

  extern "C"
  JNIEXPORT void JNICALL
  Java_com_aivos_wabot_app_BotEngine_registerNodeDataDirPath(
          JNIEnv *env, jobject, jstring dataDir) {
      const char* nativeDataDir = env->GetStringUTFChars(dataDir, 0);
      rn_register_node_data_dir_path(nativeDataDir);
      env->ReleaseStringUTFChars(dataDir, nativeDataDir);
  }

  #define ADBTAG "WABOT-NODEJS"

  void rcv_message(const char* channel_name, const char* msg) {
      JNIEnv *env = cacheEnvPointer;
      if (!env) return;
      jclass cls = env->FindClass("com/aivos/wabot/app/BotEngine");
      if (cls != nullptr) {
          jmethodID m = env->GetStaticMethodID(cls, "sendMessageToApplication",
              "(Ljava/lang/String;Ljava/lang/String;)V");
          if (m != nullptr) {
              jstring jChannel = env->NewStringUTF(channel_name);
              jstring jMsg = env->NewStringUTF(msg);
              env->CallStaticVoidMethod(cls, m, jChannel, jMsg);
              env->DeleteLocalRef(jChannel);
              env->DeleteLocalRef(jMsg);
          }
          env->DeleteLocalRef(cls);
      }
  }

  int pipe_stdout[2];
  int pipe_stderr[2];
  pthread_t thread_stdout;
  pthread_t thread_stderr;

  void *thread_stderr_func(void*) {
      ssize_t sz; char buf[2048];
      while ((sz = read(pipe_stderr[0], buf, sizeof buf - 1)) > 0) {
          if (buf[sz - 1] == '\n') --sz;
          buf[sz] = 0;
          __android_log_write(ANDROID_LOG_ERROR, ADBTAG, buf);
      }
      return 0;
  }

  void *thread_stdout_func(void*) {
      ssize_t sz; char buf[2048];
      while ((sz = read(pipe_stdout[0], buf, sizeof buf - 1)) > 0) {
          if (buf[sz - 1] == '\n') --sz;
          buf[sz] = 0;
          __android_log_write(ANDROID_LOG_INFO, ADBTAG, buf);
      }
      return 0;
  }

  int start_redirecting_stdout_stderr() {
      setvbuf(stdout, 0, _IONBF, 0);
      pipe(pipe_stdout);
      dup2(pipe_stdout[1], STDOUT_FILENO);
      setvbuf(stderr, 0, _IONBF, 0);
      pipe(pipe_stderr);
      dup2(pipe_stderr[1], STDERR_FILENO);
      if (pthread_create(&thread_stdout, 0, thread_stdout_func, 0) == -1) return -1;
      pthread_detach(thread_stdout);
      if (pthread_create(&thread_stderr, 0, thread_stderr_func, 0) == -1) return -1;
      pthread_detach(thread_stderr);
      return 0;
  }

  extern "C" jint JNICALL
  Java_com_aivos_wabot_app_BotEngine_startNodeWithArguments(
          JNIEnv *env, jobject,
          jobjectArray arguments, jstring modulesPath,
          jboolean option_redirectOutputToLogcat) {

      const char* path_path = env->GetStringUTFChars(modulesPath, 0);
      setenv("NODE_PATH", path_path, 1);
      env->ReleaseStringUTFChars(modulesPath, path_path);

      jsize argument_count = env->GetArrayLength(arguments);
      int c_arguments_size = 0;
      for (int i = 0; i < argument_count; i++) {
          c_arguments_size += strlen(env->GetStringUTFChars(
              (jstring)env->GetObjectArrayElement(arguments, i), 0)) + 1;
      }

      char* args_buffer = (char*)calloc(c_arguments_size, sizeof(char));
      char* argv[argument_count];
      char* cur = args_buffer;

      for (int i = 0; i < argument_count; i++) {
          const char* arg = env->GetStringUTFChars(
              (jstring)env->GetObjectArrayElement(arguments, i), 0);
          strncpy(cur, arg, strlen(arg));
          argv[i] = cur;
          cur += strlen(cur) + 1;
      }

      rn_register_bridge_cb(&rcv_message);
      cacheEnvPointer = env;

      if (option_redirectOutputToLogcat) {
          if (start_redirecting_stdout_stderr() == -1) {
              __android_log_write(ANDROID_LOG_ERROR, ADBTAG,
                  "Couldn't redirect stdout/stderr to logcat.");
          }
      }

      return jint(callintoNode(argument_count, argv));
  }
  