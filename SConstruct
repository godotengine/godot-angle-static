#!/usr/bin/env python

import os
import platform
import sys

EnsureSConsVersion(4, 0)


def add_sources(sources, dir, extension):
    for f in os.listdir(dir):
        if f.endswith("." + extension):
            sources.append(dir + "/" + f)


def normalize_path(val):
    return val if os.path.isabs(val) else os.path.join(env.Dir("#").abspath, val)


# Try to detect the host platform automatically.
# This is used if no `platform` argument is passed
if sys.platform == "darwin":
    default_platform = "macos"
elif sys.platform == "win32" or sys.platform == "msys":
    default_platform = "windows"
elif ARGUMENTS.get("platform", ""):
    default_platform = ARGUMENTS.get("platform")
else:
    raise ValueError("Could not detect platform automatically, please specify with platform=<platform>")

try:
    Import("env")
except:
    # Default tools with no platform defaults to gnu toolchain.
    # We apply platform specific toolchains via our custom tools.
    env = Environment(tools=["default"], PLATFORM="")

env.PrependENVPath("PATH", os.getenv("PATH"))

# Default num_jobs to local cpu count if not user specified.
# SCons has a peculiarity where user-specified options won't be overridden
# by SetOption, so we can rely on this to know if we should use our default.
initial_num_jobs = env.GetOption("num_jobs")
altered_num_jobs = initial_num_jobs + 1
env.SetOption("num_jobs", altered_num_jobs)
if env.GetOption("num_jobs") == altered_num_jobs:
    cpu_count = os.cpu_count()
    if cpu_count is None:
        print("Couldn't auto-detect CPU count to configure build parallelism. Specify it with the -j argument.")
    else:
        safer_cpu_count = cpu_count if cpu_count <= 4 else cpu_count - 1
        print(
            "Auto-detected %d CPU cores available for build parallelism. Using %d cores by default. You can override it with the -j argument."
            % (cpu_count, safer_cpu_count)
        )
        env.SetOption("num_jobs", safer_cpu_count)

# Custom options and profile flags.
customs = ["custom.py"]
profile = ARGUMENTS.get("profile", "")
if profile:
    if os.path.isfile(profile):
        customs.append(profile)
    elif os.path.isfile(profile + ".py"):
        customs.append(profile + ".py")
opts = Variables(customs, ARGUMENTS)

platforms = ("macos", "ios", "windows")
opts.Add(
    EnumVariable(
        key="platform",
        help="Target platform",
        default=env.get("platform", default_platform),
        allowed_values=platforms,
        ignorecase=2,
    )
)

# Add platform options
tools = {}
for pl in platforms:
    tool = Tool(pl, toolpath=["godot-tools"])
    if hasattr(tool, "options"):
        tool.options(opts)
    tools[pl] = tool

# CPU architecture options.
architecture_array = ["", "universal", "x86_32", "x86_64", "arm32", "arm64", "rv64", "ppc32", "ppc64", "wasm32"]
architecture_aliases = {
    "x64": "x86_64",
    "amd64": "x86_64",
    "armv7": "arm32",
    "armv8": "arm64",
    "arm64v8": "arm64",
    "aarch64": "arm64",
    "rv": "rv64",
    "riscv": "rv64",
    "riscv64": "rv64",
    "ppcle": "ppc32",
    "ppc": "ppc32",
    "ppc64le": "ppc64",
}
opts.Add(
    EnumVariable(
        key="arch",
        help="CPU architecture",
        default=env.get("arch", ""),
        allowed_values=architecture_array,
        map=architecture_aliases,
    )
)

# Targets flags tool (optimizations, debug symbols)
target_tool = Tool("targets", toolpath=["godot-tools"])
target_tool.options(opts)

opts.Update(env)
Help(opts.GenerateHelpText(env))

# Process CPU architecture argument.
if env["arch"] == "":
    # No architecture specified. Default to arm64 if building for Android,
    # universal if building for macOS or iOS, wasm32 if building for web,
    # otherwise default to the host architecture.
    if env["platform"] in ["macos", "ios"]:
        env["arch"] = "universal"
    else:
        host_machine = platform.machine().lower()
        if host_machine in architecture_array:
            env["arch"] = host_machine
        elif host_machine in architecture_aliases.keys():
            env["arch"] = architecture_aliases[host_machine]
        elif "86" in host_machine:
            # Catches x86, i386, i486, i586, i686, etc.
            env["arch"] = "x86_32"
        else:
            print("Unsupported CPU architecture: " + host_machine)
            Exit()

tool = Tool(env["platform"], toolpath=["godot-tools"])

if tool is None or not tool.exists(env):
    raise ValueError("Required toolchain not found for platform " + env["platform"])

tool.generate(env)
target_tool.generate(env)

# Detect and print a warning listing unknown SCons variables to ease troubleshooting.
unknown = opts.UnknownVariables()
if unknown:
    print("WARNING: Unknown SCons variables were passed and will be ignored:")
    for item in unknown.items():
        print("    " + item[0] + "=" + item[1])

print("Building for architecture " + env["arch"] + " on platform " + env["platform"])

# Require C++17
if env.get("is_msvc", False):
    env.Append(CXXFLAGS=["/std:c++17"])
else:
    env.Append(CXXFLAGS=["-std=c++17"])

if env["platform"] == "macos":
    # CPU architecture.
    if env["arch"] == "arm64":
        print("Building for macOS 11.0+.")
        env.Append(ASFLAGS=["-mmacosx-version-min=11.0"])
        env.Append(CCFLAGS=["-mmacosx-version-min=11.0"])
        env.Append(LINKFLAGS=["-mmacosx-version-min=11.0"])
    elif env["arch"] == "x86_64":
        print("Building for macOS 10.13+.")
        env.Append(ASFLAGS=["-mmacosx-version-min=10.13"])
        env.Append(CCFLAGS=["-mmacosx-version-min=10.13"])
        env.Append(LINKFLAGS=["-mmacosx-version-min=10.13"])
elif env["platform"] == "windows":
    env.AppendUnique(CPPDEFINES=["WINVER=0x0603", "_WIN32_WINNT=0x0603"])


scons_cache_path = os.environ.get("SCONS_CACHE")
if scons_cache_path is not None:
    CacheDir(scons_cache_path)
    Decider("MD5")

angle_sources = [
    "angle/src/common/CompiledShaderState.cpp",
    "angle/src/common/Float16ToFloat32.cpp",
    "angle/src/common/MemoryBuffer.cpp",
    "angle/src/common/PackedCLEnums_autogen.cpp",
    "angle/src/common/PackedEGLEnums_autogen.cpp",
    "angle/src/common/PackedEnums.cpp",
    "angle/src/common/PackedGLEnums_autogen.cpp",
    "angle/src/common/PoolAlloc.cpp",
    "angle/src/common/RingBufferAllocator.cpp",
    "angle/src/common/SimpleMutex.cpp",
    "angle/src/common/WorkerThread.cpp",
    "angle/src/common/aligned_memory.cpp",
    "angle/src/common/android_util.cpp",
    "angle/src/common/angle_version_info.cpp",
    "angle/src/common/angleutils.cpp",
    "angle/src/common/debug.cpp",
    "angle/src/common/entry_points_enum_autogen.cpp",
    "angle/src/common/event_tracer.cpp",
    "angle/src/common/gl_enum_utils.cpp",
    "angle/src/common/gl_enum_utils_autogen.cpp",
    "angle/src/common/mathutil.cpp",
    "angle/src/common/matrix_utils.cpp",
    "angle/src/common/platform_helpers.cpp",
    "angle/src/common/string_utils.cpp",
    "angle/src/common/system_utils.cpp",
    "angle/src/common/tls.cpp",
    "angle/src/common/uniform_type_info_autogen.cpp",
    "angle/src/common/utilities.cpp",
    "angle/src/common/base/anglebase/sha1.cc",
    "angle/src/compiler/preprocessor/DiagnosticsBase.cpp",
    "angle/src/compiler/preprocessor/DirectiveHandlerBase.cpp",
    "angle/src/compiler/preprocessor/DirectiveParser.cpp",
    "angle/src/compiler/preprocessor/Input.cpp",
    "angle/src/compiler/preprocessor/Lexer.cpp",
    "angle/src/compiler/preprocessor/Macro.cpp",
    "angle/src/compiler/preprocessor/MacroExpander.cpp",
    "angle/src/compiler/preprocessor/Preprocessor.cpp",
    "angle/src/compiler/preprocessor/Token.cpp",
    "angle/src/compiler/preprocessor/preprocessor_lex_autogen.cpp",
    "angle/src/compiler/preprocessor/preprocessor_tab_autogen.cpp",
    "angle/src/compiler/translator/BaseTypes.cpp",
    "angle/src/compiler/translator/BuiltInFunctionEmulator.cpp",
    "angle/src/compiler/translator/CallDAG.cpp",
    "angle/src/compiler/translator/CodeGen.cpp",
    "angle/src/compiler/translator/CollectVariables.cpp",
    "angle/src/compiler/translator/Compiler.cpp",
    "angle/src/compiler/translator/ConstantUnion.cpp",
    "angle/src/compiler/translator/Declarator.cpp",
    "angle/src/compiler/translator/Diagnostics.cpp",
    "angle/src/compiler/translator/DirectiveHandler.cpp",
    "angle/src/compiler/translator/ExtensionBehavior.cpp",
    "angle/src/compiler/translator/FlagStd140Structs.cpp",
    "angle/src/compiler/translator/FunctionLookup.cpp",
    "angle/src/compiler/translator/HashNames.cpp",
    "angle/src/compiler/translator/ImmutableStringBuilder.cpp",
    "angle/src/compiler/translator/ImmutableString_ESSL_autogen.cpp",
    "angle/src/compiler/translator/InfoSink.cpp",
    "angle/src/compiler/translator/Initialize.cpp",
    "angle/src/compiler/translator/InitializeDll.cpp",
    "angle/src/compiler/translator/IntermNode.cpp",
    "angle/src/compiler/translator/IntermRebuild.cpp",
    "angle/src/compiler/translator/IsASTDepthBelowLimit.cpp",
    "angle/src/compiler/translator/Operator.cpp",
    "angle/src/compiler/translator/OutputTree.cpp",
    "angle/src/compiler/translator/ParseContext.cpp",
    "angle/src/compiler/translator/PoolAlloc.cpp",
    "angle/src/compiler/translator/QualifierTypes.cpp",
    "angle/src/compiler/translator/ShaderLang.cpp",
    "angle/src/compiler/translator/ShaderVars.cpp",
    "angle/src/compiler/translator/Symbol.cpp",
    "angle/src/compiler/translator/SymbolTable.cpp",
    "angle/src/compiler/translator/SymbolTable_ESSL_autogen.cpp",
    "angle/src/compiler/translator/SymbolUniqueId.cpp",
    "angle/src/compiler/translator/Types.cpp",
    "angle/src/compiler/translator/ValidateAST.cpp",
    "angle/src/compiler/translator/ValidateBarrierFunctionCall.cpp",
    "angle/src/compiler/translator/ValidateClipCullDistance.cpp",
    "angle/src/compiler/translator/ValidateGlobalInitializer.cpp",
    "angle/src/compiler/translator/ValidateLimitations.cpp",
    "angle/src/compiler/translator/ValidateMaxParameters.cpp",
    "angle/src/compiler/translator/ValidateOutputs.cpp",
    "angle/src/compiler/translator/ValidateSwitch.cpp",
    "angle/src/compiler/translator/ValidateTypeSizeLimitations.cpp",
    "angle/src/compiler/translator/ValidateVaryingLocations.cpp",
    "angle/src/compiler/translator/VariablePacker.cpp",
    "angle/src/compiler/translator/blocklayout.cpp",
    "angle/src/compiler/translator/glslang_lex_autogen.cpp",
    "angle/src/compiler/translator/glslang_tab_autogen.cpp",
    "angle/src/compiler/translator/util.cpp",
    "angle/src/compiler/translator/glsl/BuiltInFunctionEmulatorGLSL.cpp",
    "angle/src/compiler/translator/glsl/ExtensionGLSL.cpp",
    "angle/src/compiler/translator/glsl/OutputESSL.cpp",
    "angle/src/compiler/translator/glsl/OutputGLSL.cpp",
    "angle/src/compiler/translator/glsl/OutputGLSLBase.cpp",
    "angle/src/compiler/translator/glsl/TranslatorESSL.cpp",
    "angle/src/compiler/translator/glsl/TranslatorGLSL.cpp",
    "angle/src/compiler/translator/glsl/VersionGLSL.cpp",
    "angle/src/compiler/translator/tree_ops/ClampFragDepth.cpp",
    "angle/src/compiler/translator/tree_ops/ClampIndirectIndices.cpp",
    "angle/src/compiler/translator/tree_ops/ClampPointSize.cpp",
    "angle/src/compiler/translator/tree_ops/DeclareAndInitBuiltinsForInstancedMultiview.cpp",
    "angle/src/compiler/translator/tree_ops/DeclarePerVertexBlocks.cpp",
    "angle/src/compiler/translator/tree_ops/DeferGlobalInitializers.cpp",
    "angle/src/compiler/translator/tree_ops/EmulateGLFragColorBroadcast.cpp",
    "angle/src/compiler/translator/tree_ops/EmulateMultiDrawShaderBuiltins.cpp",
    "angle/src/compiler/translator/tree_ops/FoldExpressions.cpp",
    "angle/src/compiler/translator/tree_ops/ForcePrecisionQualifier.cpp",
    "angle/src/compiler/translator/tree_ops/InitializeVariables.cpp",
    "angle/src/compiler/translator/tree_ops/MonomorphizeUnsupportedFunctions.cpp",
    "angle/src/compiler/translator/tree_ops/PreTransformTextureCubeGradDerivatives.cpp",
    "angle/src/compiler/translator/tree_ops/PruneEmptyCases.cpp",
    "angle/src/compiler/translator/tree_ops/PruneNoOps.cpp",
    "angle/src/compiler/translator/tree_ops/RecordConstantPrecision.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveArrayLengthMethod.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveAtomicCounterBuiltins.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveDynamicIndexing.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveInactiveInterfaceVariables.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveInvariantDeclaration.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveUnreferencedVariables.cpp",
    "angle/src/compiler/translator/tree_ops/RescopeGlobalVariables.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteArrayOfArrayOfOpaqueUniforms.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteAtomicCounters.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteCubeMapSamplersAs2DArray.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteDfdy.cpp",
    "angle/src/compiler/translator/tree_ops/RewritePixelLocalStorage.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteStructSamplers.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteTexelFetchOffset.cpp",
    "angle/src/compiler/translator/tree_ops/SeparateDeclarations.cpp",
    "angle/src/compiler/translator/tree_ops/SeparateStructFromFunctionDeclarations.cpp",
    "angle/src/compiler/translator/tree_ops/SeparateStructFromUniformDeclarations.cpp",
    "angle/src/compiler/translator/tree_ops/SimplifyLoopConditions.cpp",
    "angle/src/compiler/translator/tree_ops/SplitSequenceOperator.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/RegenerateStructNames.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/RewriteRepeatedAssignToSwizzled.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/ScalarizeVecAndMatConstructorArgs.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/UseInterfaceBlockFields.cpp",
    "angle/src/compiler/translator/tree_util/DriverUniform.cpp",
    "angle/src/compiler/translator/tree_util/FindFunction.cpp",
    "angle/src/compiler/translator/tree_util/FindMain.cpp",
    "angle/src/compiler/translator/tree_util/FindPreciseNodes.cpp",
    "angle/src/compiler/translator/tree_util/FindSymbolNode.cpp",
    "angle/src/compiler/translator/tree_util/IntermNodePatternMatcher.cpp",
    "angle/src/compiler/translator/tree_util/IntermNode_util.cpp",
    "angle/src/compiler/translator/tree_util/IntermTraverse.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceArrayOfMatrixVarying.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceClipCullDistanceVariable.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceShadowingVariables.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceVariable.cpp",
    "angle/src/compiler/translator/tree_util/RewriteSampleMaskVariable.cpp",
    "angle/src/compiler/translator/tree_util/RunAtTheBeginningOfShader.cpp",
    "angle/src/compiler/translator/tree_util/RunAtTheEndOfShader.cpp",
    "angle/src/compiler/translator/tree_util/SpecializationConstant.cpp",
    "angle/src/gpu_info_util/SystemInfo.cpp",
    "angle/src/libANGLE/AttributeMap.cpp",
    "angle/src/libANGLE/BlobCache.cpp",
    "angle/src/libANGLE/Buffer.cpp",
    "angle/src/libANGLE/CLBuffer.cpp",
    "angle/src/libANGLE/CLCommandQueue.cpp",
    "angle/src/libANGLE/CLContext.cpp",
    "angle/src/libANGLE/CLDevice.cpp",
    "angle/src/libANGLE/CLEvent.cpp",
    "angle/src/libANGLE/CLImage.cpp",
    "angle/src/libANGLE/CLKernel.cpp",
    "angle/src/libANGLE/CLMemory.cpp",
    "angle/src/libANGLE/CLObject.cpp",
    "angle/src/libANGLE/CLPlatform.cpp",
    "angle/src/libANGLE/CLProgram.cpp",
    "angle/src/libANGLE/CLSampler.cpp",
    "angle/src/libANGLE/Caps.cpp",
    "angle/src/libANGLE/Compiler.cpp",
    "angle/src/libANGLE/Config.cpp",
    "angle/src/libANGLE/Context.cpp",
    "angle/src/libANGLE/ContextMutex.cpp",
    "angle/src/libANGLE/Context_gl.cpp",
    "angle/src/libANGLE/Context_gles_1_0.cpp",
    "angle/src/libANGLE/Debug.cpp",
    "angle/src/libANGLE/Device.cpp",
    "angle/src/libANGLE/Display.cpp",
    "angle/src/libANGLE/EGLSync.cpp",
    "angle/src/libANGLE/Error.cpp",
    "angle/src/libANGLE/Fence.cpp",
    "angle/src/libANGLE/Framebuffer.cpp",
    "angle/src/libANGLE/FramebufferAttachment.cpp",
    "angle/src/libANGLE/GLES1Renderer.cpp",
    "angle/src/libANGLE/GLES1State.cpp",
    "angle/src/libANGLE/GlobalMutex.cpp",
    "angle/src/libANGLE/HandleAllocator.cpp",
    "angle/src/libANGLE/Image.cpp",
    "angle/src/libANGLE/ImageIndex.cpp",
    "angle/src/libANGLE/IndexRangeCache.cpp",
    "angle/src/libANGLE/LoggingAnnotator.cpp",
    "angle/src/libANGLE/MemoryObject.cpp",
    "angle/src/libANGLE/MemoryProgramCache.cpp",
    "angle/src/libANGLE/MemoryShaderCache.cpp",
    "angle/src/libANGLE/Observer.cpp",
    "angle/src/libANGLE/Overlay.cpp",
    "angle/src/libANGLE/OverlayWidgets.cpp",
    "angle/src/libANGLE/Overlay_autogen.cpp",
    "angle/src/libANGLE/Overlay_font_autogen.cpp",
    "angle/src/libANGLE/PixelLocalStorage.cpp",
    "angle/src/libANGLE/Platform.cpp",
    "angle/src/libANGLE/Program.cpp",
    "angle/src/libANGLE/ProgramExecutable.cpp",
    "angle/src/libANGLE/ProgramLinkedResources.cpp",
    "angle/src/libANGLE/ProgramPipeline.cpp",
    "angle/src/libANGLE/Query.cpp",
    "angle/src/libANGLE/Renderbuffer.cpp",
    "angle/src/libANGLE/ResourceManager.cpp",
    "angle/src/libANGLE/Sampler.cpp",
    "angle/src/libANGLE/Semaphore.cpp",
    "angle/src/libANGLE/Shader.cpp",
    "angle/src/libANGLE/ShareGroup.cpp",
    "angle/src/libANGLE/State.cpp",
    "angle/src/libANGLE/Stream.cpp",
    "angle/src/libANGLE/Surface.cpp",
    "angle/src/libANGLE/Texture.cpp",
    "angle/src/libANGLE/Thread.cpp",
    "angle/src/libANGLE/TransformFeedback.cpp",
    "angle/src/libANGLE/Uniform.cpp",
    "angle/src/libANGLE/VaryingPacking.cpp",
    "angle/src/libANGLE/VertexArray.cpp",
    "angle/src/libANGLE/VertexAttribute.cpp",
    "angle/src/libANGLE/angletypes.cpp",
    "angle/src/libANGLE/cl_utils.cpp",
    "angle/src/libANGLE/context_private_call_gl.cpp",
    "angle/src/libANGLE/context_private_call_gles.cpp",
    "angle/src/libANGLE/entry_points_utils.cpp",
    "angle/src/libANGLE/es3_copy_conversion_table_autogen.cpp",
    "angle/src/libANGLE/format_map_autogen.cpp",
    "angle/src/libANGLE/format_map_desktop.cpp",
    "angle/src/libANGLE/formatutils.cpp",
    "angle/src/libANGLE/gles_extensions_autogen.cpp",
    "angle/src/libANGLE/queryconversions.cpp",
    "angle/src/libANGLE/queryutils.cpp",
    "angle/src/libANGLE/validationCL.cpp",
    "angle/src/libANGLE/validationEGL.cpp",
    "angle/src/libANGLE/validationES.cpp",
    "angle/src/libANGLE/validationES1.cpp",
    "angle/src/libANGLE/validationES2.cpp",
    "angle/src/libANGLE/validationES3.cpp",
    "angle/src/libANGLE/validationES31.cpp",
    "angle/src/libANGLE/validationES32.cpp",
    "angle/src/libANGLE/validationESEXT.cpp",
    "angle/src/libANGLE/validationGL1.cpp",
    "angle/src/libANGLE/validationGL2.cpp",
    "angle/src/libANGLE/validationGL3.cpp",
    "angle/src/libANGLE/validationGL4.cpp",
    "angle/src/libANGLE/capture/FrameCapture_mock.cpp",
    "angle/src/libANGLE/capture/serialize_mock.cpp",
    "angle/src/libANGLE/renderer/BufferImpl.cpp",
    "angle/src/libANGLE/renderer/CLCommandQueueImpl.cpp",
    "angle/src/libANGLE/renderer/CLContextImpl.cpp",
    "angle/src/libANGLE/renderer/CLDeviceImpl.cpp",
    "angle/src/libANGLE/renderer/CLEventImpl.cpp",
    "angle/src/libANGLE/renderer/CLExtensions.cpp",
    "angle/src/libANGLE/renderer/CLKernelImpl.cpp",
    "angle/src/libANGLE/renderer/CLMemoryImpl.cpp",
    "angle/src/libANGLE/renderer/CLPlatformImpl.cpp",
    "angle/src/libANGLE/renderer/CLProgramImpl.cpp",
    "angle/src/libANGLE/renderer/CLSamplerImpl.cpp",
    "angle/src/libANGLE/renderer/ContextImpl.cpp",
    "angle/src/libANGLE/renderer/DeviceImpl.cpp",
    "angle/src/libANGLE/renderer/DisplayImpl.cpp",
    "angle/src/libANGLE/renderer/EGLReusableSync.cpp",
    "angle/src/libANGLE/renderer/EGLSyncImpl.cpp",
    "angle/src/libANGLE/renderer/Format_table_autogen.cpp",
    "angle/src/libANGLE/renderer/FramebufferImpl.cpp",
    "angle/src/libANGLE/renderer/ImageImpl.cpp",
    "angle/src/libANGLE/renderer/ProgramImpl.cpp",
    "angle/src/libANGLE/renderer/ProgramPipelineImpl.cpp",
    "angle/src/libANGLE/renderer/QueryImpl.cpp",
    "angle/src/libANGLE/renderer/RenderbufferImpl.cpp",
    "angle/src/libANGLE/renderer/ShaderImpl.cpp",
    "angle/src/libANGLE/renderer/SurfaceImpl.cpp",
    "angle/src/libANGLE/renderer/TextureImpl.cpp",
    "angle/src/libANGLE/renderer/TransformFeedbackImpl.cpp",
    "angle/src/libANGLE/renderer/VertexArrayImpl.cpp",
    "angle/src/libANGLE/renderer/driver_utils.cpp",
    "angle/src/libANGLE/renderer/load_functions_table_autogen.cpp",
    "angle/src/libANGLE/renderer/renderer_utils.cpp",
    "angle/src/image_util/AstcDecompressor.cpp",
    "angle/src/image_util/copyimage.cpp",
    "angle/src/image_util/imageformats.cpp",
    "angle/src/image_util/loadimage_astc.cpp",
    "angle/src/image_util/loadimage_etc.cpp",
    "angle/src/image_util/loadimage_paletted.cpp",
    "angle/src/image_util/loadimage.cpp",
    "angle/src/image_util/storeimage_paletted.cpp",
    "angle/src/common/third_party/xxhash/xxhash.c",
    "third_party/zlib/google/compression_utils_portable.cc",
    "third_party/zlib/adler32.c",
    "third_party/zlib/compress.c",
    "third_party/zlib/cpu_features.c",
    "third_party/zlib/crc_folding.c",
    "third_party/zlib/crc32.c",
    "third_party/zlib/deflate.c",
    "third_party/zlib/gzclose.c",
    "third_party/zlib/gzlib.c",
    "third_party/zlib/gzread.c",
    "third_party/zlib/gzwrite.c",
    "third_party/zlib/infback.c",
    "third_party/zlib/inffast.c",
    "third_party/zlib/inflate.c",
    "third_party/zlib/inftrees.c",
    "third_party/zlib/trees.c",
    "third_party/zlib/uncompr.c",
    "third_party/zlib/zutil.c",
]
if env["platform"] == "macos":
    angle_sources += [
        "angle/src/common/system_utils_apple.cpp",
        "angle/src/common/system_utils_mac.cpp",
        "angle/src/gpu_info_util/SystemInfo_macos.mm",
        "angle/src/common/gl/cgl/FunctionsCGL.cpp",
        "angle/src/libANGLE/renderer/driver_utils_mac.mm",
        "angle/src/libANGLE/renderer/gl/cgl/ContextCGL.cpp",
        "angle/src/libANGLE/renderer/gl/cgl/DeviceCGL.cpp",
        "angle/src/libANGLE/renderer/gl/cgl/DisplayCGL.mm",
        "angle/src/libANGLE/renderer/gl/cgl/IOSurfaceSurfaceCGL.cpp",
        "angle/src/libANGLE/renderer/gl/cgl/PbufferSurfaceCGL.cpp",
        "angle/src/libANGLE/renderer/gl/cgl/WindowSurfaceCGL.mm",
    ]
if env["platform"] == "ios":
    angle_sources += [
        "angle/src/common/system_utils_ios.mm",
        "angle/src/gpu_info_util/SystemInfo_ios.cpp",
        "angle/src/libANGLE/renderer/driver_utils_ios.mm",
        "angle/src/libANGLE/renderer/gl/eagl/ContextEAGL.cpp",
        "angle/src/libANGLE/renderer/gl/eagl/DeviceEAGL.cpp",
        "angle/src/libANGLE/renderer/gl/eagl/DisplayEAGL.mm",
        "angle/src/libANGLE/renderer/gl/eagl/FunctionsEAGL.mm",
        "angle/src/libANGLE/renderer/gl/eagl/IOSurfaceSurfaceEAGL.mm",
        "angle/src/libANGLE/renderer/gl/eagl/PbufferSurfaceEAGL.cpp",
        "angle/src/libANGLE/renderer/gl/eagl/WindowSurfaceEAGL.mm",
    ]
if env["platform"] == "macos" or env["platform"] == "ios":
    angle_sources += [
        "angle/src/common/apple_platform_utils.mm",
        "angle/src/common/system_utils_posix.cpp",
        "angle/src/compiler/translator/msl/AstHelpers.cpp",
        "angle/src/compiler/translator/msl/ConstantNames.cpp",
        "angle/src/compiler/translator/msl/DiscoverDependentFunctions.cpp",
        "angle/src/compiler/translator/msl/DiscoverEnclosingFunctionTraverser.cpp",
        "angle/src/compiler/translator/msl/DriverUniformMetal.cpp",
        "angle/src/compiler/translator/msl/EmitMetal.cpp",
        "angle/src/compiler/translator/msl/IdGen.cpp",
        "angle/src/compiler/translator/msl/Layout.cpp",
        "angle/src/compiler/translator/msl/MapFunctionsToDefinitions.cpp",
        "angle/src/compiler/translator/msl/MapSymbols.cpp",
        "angle/src/compiler/translator/msl/ModifyStruct.cpp",
        "angle/src/compiler/translator/msl/Name.cpp",
        "angle/src/compiler/translator/msl/Pipeline.cpp",
        "angle/src/compiler/translator/msl/ProgramPrelude.cpp",
        "angle/src/compiler/translator/msl/RewritePipelines.cpp",
        "angle/src/compiler/translator/msl/SymbolEnv.cpp",
        "angle/src/compiler/translator/msl/ToposortStructs.cpp",
        "angle/src/compiler/translator/msl/TranslatorMSL.cpp",
        "angle/src/compiler/translator/msl/UtilsMSL.cpp",
        "angle/src/compiler/translator/tree_ops/glsl/apple/AddAndTrueToLoopCondition.cpp",
        "angle/src/compiler/translator/tree_ops/glsl/apple/RewriteDoWhile.cpp",
        "angle/src/compiler/translator/tree_ops/glsl/apple/RewriteRowMajorMatrices.cpp",
        "angle/src/compiler/translator/tree_ops/glsl/apple/RewriteUnaryMinusOperatorFloat.cpp",
        "angle/src/compiler/translator/tree_ops/glsl/apple/UnfoldShortCircuitAST.cpp",
        "angle/src/compiler/translator/tree_ops/msl/AddExplicitTypeCasts.cpp",
        "angle/src/compiler/translator/tree_ops/msl/ConvertUnsupportedConstructorsToFunctionCalls.cpp",
        "angle/src/compiler/translator/tree_ops/msl/FixTypeConstructors.cpp",
        "angle/src/compiler/translator/tree_ops/msl/GuardFragDepthWrite.cpp",
        "angle/src/compiler/translator/tree_ops/msl/HoistConstants.cpp",
        "angle/src/compiler/translator/tree_ops/msl/IntroduceVertexIndexID.cpp",
        "angle/src/compiler/translator/tree_ops/msl/NameEmbeddedUniformStructsMetal.cpp",
        "angle/src/compiler/translator/tree_ops/msl/ReduceInterfaceBlocks.cpp",
        "angle/src/compiler/translator/tree_ops/msl/RewriteCaseDeclarations.cpp",
        "angle/src/compiler/translator/tree_ops/msl/RewriteInterpolants.cpp",
        "angle/src/compiler/translator/tree_ops/msl/RewriteOutArgs.cpp",
        "angle/src/compiler/translator/tree_ops/msl/RewriteUnaddressableReferences.cpp",
        "angle/src/compiler/translator/tree_ops/msl/SeparateCompoundExpressions.cpp",
        "angle/src/compiler/translator/tree_ops/msl/SeparateCompoundStructDeclarations.cpp",
        "angle/src/compiler/translator/tree_ops/msl/TransposeRowMajorMatrices.cpp",
        "angle/src/compiler/translator/tree_ops/msl/WrapMain.cpp",
        "angle/src/gpu_info_util/SystemInfo_apple.mm",
        "angle/src/libANGLE/renderer/driver_utils_mac.mm",
        "angle/src/libANGLE/renderer/metal/BufferMtl.mm",
        "angle/src/libANGLE/renderer/metal/CompilerMtl.mm",
        "angle/src/libANGLE/renderer/metal/ContextMtl.mm",
        "angle/src/libANGLE/renderer/metal/DeviceMtl.mm",
        "angle/src/libANGLE/renderer/metal/DisplayMtl.mm",
        "angle/src/libANGLE/renderer/metal/FrameBufferMtl.mm",
        "angle/src/libANGLE/renderer/metal/IOSurfaceSurfaceMtl.mm",
        "angle/src/libANGLE/renderer/metal/ImageMtl.mm",
        "angle/src/libANGLE/renderer/metal/ProgramExecutableMtl.mm",
        "angle/src/libANGLE/renderer/metal/ProgramMtl.mm",
        "angle/src/libANGLE/renderer/metal/ProvokingVertexHelper.mm",
        "angle/src/libANGLE/renderer/metal/QueryMtl.mm",
        "angle/src/libANGLE/renderer/metal/RenderBufferMtl.mm",
        "angle/src/libANGLE/renderer/metal/RenderTargetMtl.mm",
        "angle/src/libANGLE/renderer/metal/SamplerMtl.mm",
        "angle/src/libANGLE/renderer/metal/ShaderMtl.mm",
        "angle/src/libANGLE/renderer/metal/SurfaceMtl.mm",
        "angle/src/libANGLE/renderer/metal/SyncMtl.mm",
        "angle/src/libANGLE/renderer/metal/TextureMtl.mm",
        "angle/src/libANGLE/renderer/metal/TransformFeedbackMtl.mm",
        "angle/src/libANGLE/renderer/metal/VertexArrayMtl.mm",
        "angle/src/libANGLE/renderer/metal/blocklayoutMetal.cpp",
        "angle/src/libANGLE/renderer/metal/mtl_buffer_manager.mm",
        "angle/src/libANGLE/renderer/metal/mtl_buffer_pool.mm",
        "angle/src/libANGLE/renderer/metal/mtl_command_buffer.mm",
        "angle/src/libANGLE/renderer/metal/mtl_common.mm",
        "angle/src/libANGLE/renderer/metal/mtl_context_device.mm",
        "angle/src/libANGLE/renderer/metal/mtl_format_table_autogen.mm",
        "angle/src/libANGLE/renderer/metal/mtl_format_utils.mm",
        "angle/src/libANGLE/renderer/metal/mtl_library_cache.mm",
        "angle/src/libANGLE/renderer/metal/mtl_msl_utils.mm",
        "angle/src/libANGLE/renderer/metal/mtl_occlusion_query_pool.mm",
        "angle/src/libANGLE/renderer/metal/mtl_pipeline_cache.mm",
        "angle/src/libANGLE/renderer/metal/mtl_render_utils.mm",
        "angle/src/libANGLE/renderer/metal/mtl_resources.mm",
        "angle/src/libANGLE/renderer/metal/mtl_state_cache.mm",
        "angle/src/libANGLE/renderer/metal/mtl_utils.mm",
        "angle/src/libANGLE/renderer/metal/process.cpp",
        "angle/src/libANGLE/renderer/metal/renderermtl_utils.cpp",
        "angle/src/libANGLE/renderer/gl/BlitGL.cpp",
        "angle/src/libANGLE/renderer/gl/BufferGL.cpp",
        "angle/src/libANGLE/renderer/gl/ClearMultiviewGL.cpp",
        "angle/src/libANGLE/renderer/gl/CompilerGL.cpp",
        "angle/src/libANGLE/renderer/gl/ContextGL.cpp",
        "angle/src/libANGLE/renderer/gl/DispatchTableGL_autogen.cpp",
        "angle/src/libANGLE/renderer/gl/DisplayGL.cpp",
        "angle/src/libANGLE/renderer/gl/FenceNVGL.cpp",
        "angle/src/libANGLE/renderer/gl/FramebufferGL.cpp",
        "angle/src/libANGLE/renderer/gl/FunctionsGL.cpp",
        "angle/src/libANGLE/renderer/gl/ImageGL.cpp",
        "angle/src/libANGLE/renderer/gl/MemoryObjectGL.cpp",
        "angle/src/libANGLE/renderer/gl/PLSProgramCache.cpp",
        "angle/src/libANGLE/renderer/gl/ProgramExecutableGL.cpp",
        "angle/src/libANGLE/renderer/gl/ProgramGL.cpp",
        "angle/src/libANGLE/renderer/gl/ProgramPipelineGL.cpp",
        "angle/src/libANGLE/renderer/gl/QueryGL.cpp",
        "angle/src/libANGLE/renderer/gl/RenderbufferGL.cpp",
        "angle/src/libANGLE/renderer/gl/RendererGL.cpp",
        "angle/src/libANGLE/renderer/gl/SamplerGL.cpp",
        "angle/src/libANGLE/renderer/gl/SemaphoreGL.cpp",
        "angle/src/libANGLE/renderer/gl/ShaderGL.cpp",
        "angle/src/libANGLE/renderer/gl/StateManagerGL.cpp",
        "angle/src/libANGLE/renderer/gl/SurfaceGL.cpp",
        "angle/src/libANGLE/renderer/gl/SyncGL.cpp",
        "angle/src/libANGLE/renderer/gl/TextureGL.cpp",
        "angle/src/libANGLE/renderer/gl/TransformFeedbackGL.cpp",
        "angle/src/libANGLE/renderer/gl/VertexArrayGL.cpp",
        "angle/src/libANGLE/renderer/gl/formatutilsgl.cpp",
        "angle/src/libANGLE/renderer/gl/null_functions.cpp",
        "angle/src/libANGLE/renderer/gl/renderergl_utils.cpp",
    ]
if env["platform"] == "windows":
    angle_sources += [
        "angle/src/common/system_utils_win.cpp",
        "angle/src/common/system_utils_win32.cpp",
        "angle/src/compiler/translator/hlsl/ASTMetadataHLSL.cpp",
        "angle/src/compiler/translator/hlsl/AtomicCounterFunctionHLSL.cpp",
        "angle/src/compiler/translator/hlsl/BuiltInFunctionEmulatorHLSL.cpp",
        "angle/src/compiler/translator/hlsl/ImageFunctionHLSL.cpp",
        "angle/src/compiler/translator/hlsl/OutputHLSL.cpp",
        "angle/src/compiler/translator/hlsl/ResourcesHLSL.cpp",
        "angle/src/compiler/translator/hlsl/ShaderStorageBlockFunctionHLSL.cpp",
        "angle/src/compiler/translator/hlsl/ShaderStorageBlockOutputHLSL.cpp",
        "angle/src/compiler/translator/hlsl/StructureHLSL.cpp",
        "angle/src/compiler/translator/hlsl/TextureFunctionHLSL.cpp",
        "angle/src/compiler/translator/hlsl/TranslatorHLSL.cpp",
        "angle/src/compiler/translator/hlsl/UtilsHLSL.cpp",
        "angle/src/compiler/translator/hlsl/blocklayoutHLSL.cpp",
        "angle/src/compiler/translator/hlsl/emulated_builtin_functions_hlsl_autogen.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/AddDefaultReturnStatements.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/AggregateAssignArraysInSSBOs.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/AggregateAssignStructsInSSBOs.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/ArrayReturnValueToOutParameter.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/BreakVariableAliasingInInnerLoops.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/ExpandIntegerPowExpressions.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/RecordUniformBlocksWithLargeArrayMember.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/RemoveSwitchFallThrough.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/RewriteAtomicFunctionExpressions.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/RewriteElseBlocks.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/RewriteExpressionsWithShaderStorageBlock.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/RewriteUnaryMinusOperatorInt.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/SeparateArrayConstructorStatements.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/SeparateArrayInitialization.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/SeparateExpressionsReturningArrays.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/UnfoldShortCircuitToIf.cpp",
        "angle/src/compiler/translator/tree_ops/hlsl/WrapSwitchStatementsInBlocks.cpp",
        "angle/src/gpu_info_util/SystemInfo_win.cpp",
        "angle/src/libANGLE/renderer/d3d_format.cpp",
        "angle/src/libANGLE/renderer/dxgi_format_map_autogen.cpp",
        "angle/src/libANGLE/renderer/dxgi_support_table_autogen.cpp",
        "angle/src/libANGLE/renderer/d3d/BufferD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/CompilerD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/DisplayD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/DynamicHLSL.cpp",
        "angle/src/libANGLE/renderer/d3d/DynamicImage2DHLSL.cpp",
        "angle/src/libANGLE/renderer/d3d/EGLImageD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/FramebufferD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/HLSLCompiler.cpp",
        "angle/src/libANGLE/renderer/d3d/ImageD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/IndexBuffer.cpp",
        "angle/src/libANGLE/renderer/d3d/IndexDataManager.cpp",
        "angle/src/libANGLE/renderer/d3d/NativeWindowD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/ProgramD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/ProgramExecutableD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/RenderTargetD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/RenderbufferD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/RendererD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/ShaderD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/ShaderExecutableD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/SurfaceD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/SwapChainD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/TextureD3D.cpp",
        "angle/src/libANGLE/renderer/d3d/VertexBuffer.cpp",
        "angle/src/libANGLE/renderer/d3d/VertexDataManager.cpp",
        "angle/src/libANGLE/renderer/d3d/driver_utils_d3d.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Blit11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Buffer11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Clear11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Context11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/DebugAnnotator11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Device11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/ExternalImageSiblingImpl11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Fence11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Framebuffer11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Image11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/IndexBuffer11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/InputLayoutCache.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/MappedSubresourceVerifier11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/PixelTransfer11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Program11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/ProgramPipeline11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Query11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/RenderStateCache.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/RenderTarget11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Renderer11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/ResourceManager11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/ShaderExecutable11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/StateManager11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/StreamProducerD3DTexture.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/SwapChain11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/TextureStorage11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/TransformFeedback11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/Trim11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/VertexArray11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/VertexBuffer11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/formatutils11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/renderer11_utils.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/texture_format_table.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/texture_format_table_autogen.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/converged/CompositorNativeWindow11.cpp",
        "angle/src/libANGLE/renderer/d3d/d3d11/win32/NativeWindow11Win32.cpp",
    ]
angle_sources_egl = [
    "angle/src/libEGL/egl_loader_autogen.cpp",
    "angle/src/libEGL/libEGL_autogen.cpp",
]
angle_sources_gles = [
    "angle/src/libGLESv2/egl_ext_stubs.cpp",
    "angle/src/libGLESv2/egl_stubs.cpp",
    "angle/src/libGLESv2/entry_points_egl_autogen.cpp",
    "angle/src/libGLESv2/entry_points_egl_ext_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_1_0_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_2_0_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_3_0_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_3_1_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_3_2_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_ext_autogen.cpp",
    "angle/src/libGLESv2/global_state.cpp",
    "angle/src/libGLESv2/libGLESv2_autogen.cpp",
    "angle/src/libGLESv2/proc_table_egl_autogen.cpp",
]
env.Append(CPPDEFINES=[("ANGLE_CAPTURE_ENABLED", 0)])
env.Append(CPPDEFINES=[("ANGLE_ENABLE_ESSL", 1)])
env.Append(CPPDEFINES=[("ANGLE_ENABLE_GLSL", 1)])
env.Append(CPPDEFINES=[("ANGLE_EXPORT", '""')])

extra_suffix = ""

if env["arch"] in ["x86_64", "arm64"]:
    env.Append(CPPDEFINES=[("ANGLE_IS_64_BIT_CPU", 1)])
else:
    env.Append(CPPDEFINES=[("ANGLE_IS_32_BIT_CPU", 1)])
if env["platform"] == "macos":
    env.Append(CPPDEFINES=["ANGLE_PLATFORM_MACOS"])
    env.Append(CPPDEFINES=[("ANGLE_IS_MAC", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_METAL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_OPENGL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_GL_DESKTOP_BACKEND", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_GL_NULL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_CGL", 1)])
    env.Append(CCFLAGS=["-fno-objc-arc", "-fno-objc-msgsend-selector-stubs", "-Wno-unused-command-line-argument"])
if env["platform"] == "windows":
    env.Append(CPPDEFINES=[("ANGLE_IS_WIN", 1)])
    env.Append(CPPDEFINES=[("ANGLE_WINDOWS_NO_FUTEX", 1)])
    env.Append(
        CPPDEFINES=[
            (
                "ANGLE_PRELOADED_D3DCOMPILER_MODULE_NAMES",
                '{ \\"d3dcompiler_47.dll\\", \\"d3dcompiler_46.dll\\", \\"d3dcompiler_43.dll\\" }',
            )
        ]
    )
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_D3D11", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_D3D11_COMPOSITOR_NATIVE_WINDOW", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_HLSL", 1)])
    env.Append(CPPDEFINES=[("NOMINMAX", 1)])
    env.Append(CPPDEFINES=[("X86_WINDOWS", 1)])
if env["platform"] == "ios":
    if env["ios_simulator"]:
        env.Append(CPPDEFINES=["ANGLE_PLATFORM_IOS_FAMILY"])
        extra_suffix = ".simulator" + extra_suffix
    else:
        env.Append(CPPDEFINES=["ANGLE_PLATFORM_IOS_FAMILY_SIMULATOR"])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_METAL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_OPENGL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_GL_NULL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_EAGL", 1)])
    env.Append(CPPDEFINES=[("GLES_SILENCE_DEPRECATION", 1)])
    env.Append(CCFLAGS=["-fno-objc-arc", "-fno-objc-msgsend-selector-stubs", "-Wno-unused-command-line-argument"])

env.Append(CPPDEFINES=[("ANGLE_STANDALONE_BUILD", 1)])
env.Append(CPPDEFINES=[("ANGLE_STATIC", 1)])
env.Append(CPPDEFINES=[("ANGLE_UTIL_EXPORT", '""')])
env.Append(CPPDEFINES=[("EGLAPI", '""')])
env.Append(CPPDEFINES=[("GL_API", '""')])
env.Append(CPPDEFINES=[("GL_APICALL", '""')])
env.Append(CPPDEFINES=[("GL_SILENCE_DEPRECATION", 1)])

env.Prepend(CPPPATH=["godot-angle"])
env.Prepend(CPPPATH=["angle/src"])
env.Prepend(CPPPATH=["angle/include"])
env.Prepend(CPPPATH=["angle/include/KHR"])
env.Prepend(CPPPATH=["angle/src/common/third_party/base"])
env.Prepend(CPPPATH=["angle/src/common/base"])
env.Prepend(CPPPATH=["angle/src/common/third_party/xxhash"])
env.Prepend(CPPPATH=["angle/src/third_party/khronos"])
env.Prepend(CPPPATH=["third_party/astc-encoder/src/Source"])
env.Prepend(CPPPATH=["third_party/zlib"])
env.Prepend(CPPPATH=["third_party/zlib/google"])

env.Append(CPPDEFINES=[("USE_AURA", 1)])

env.Append(CPPDEFINES=[("_HAS_EXCEPTIONS", "0")])
env.Append(CPPDEFINES=[("NDEBUG", 1)])
env.Append(CPPDEFINES=[("NVALGRIND", 1)])
env.Append(CPPDEFINES=[("DYNAMIC_ANNOTATIONS_ENABLED", 0)])
env.Append(CPPDEFINES=[("ANGLE_VMA_VERSION", 3000000)])
env.Append(CPPDEFINES=[("ANGLE_ENABLE_SHARE_CONTEXT_LOCK", 1)])
env.Append(CPPDEFINES=[("ANGLE_ENABLE_CONTEXT_MUTEX", 1)])
env.Append(CPPDEFINES=[("ANGLE_OUTSIDE_WEBKIT", 1)])

env_egl = env.Clone()
env_gles = env.Clone()

env.Append(CPPDEFINES=[("LIBANGLE_IMPLEMENTATION", 1)])
env.Append(CPPDEFINES=[("EGL_EGL_PROTOTYPES", 0)])

env_egl.Append(CPPDEFINES=[("EGL_EGLEXT_PROTOTYPES", 1)])
env_egl.Append(CPPDEFINES=[("EGL_EGL_PROTOTYPES", 1)])
env_egl.Append(CPPDEFINES=[("GL_GLES_PROTOTYPES", 1)])
env_egl.Append(CPPDEFINES=[("GL_GLEXT_PROTOTYPES", 1)])

env_gles.Append(CPPDEFINES=[("LIBGLESV2_IMPLEMENTATION", 1)])
env_gles.Append(CPPDEFINES=[("EGL_EGL_PROTOTYPES", 0)])
env_gles.Append(CPPDEFINES=[("GL_GLES_PROTOTYPES", 0)])

suffix = ".{}.{}".format(env["platform"], env["arch"]) + extra_suffix

# Expose it when included from another project
env["suffix"] = suffix

library = None
library_egl = None
library_gles = None
env["OBJSUFFIX"] = suffix + env["OBJSUFFIX"]
library_name = "libANGLE{}{}".format(suffix, env["LIBSUFFIX"])
library_egl_name = "libEGL{}{}".format(suffix, env["LIBSUFFIX"])
library_gles_name = "libGLES{}{}".format(suffix, env["LIBSUFFIX"])

library = env.StaticLibrary(name="ANGLE", target=env.File("bin/%s" % library_name), source=angle_sources)
library_egl = env_egl.StaticLibrary(name="EGL", target=env_egl.File("bin/%s" % library_egl_name), source=angle_sources_egl)
library_gles = env_gles.StaticLibrary(name="GLES", target=env_gles.File("bin/%s" % library_gles_name), source=angle_sources_gles)

Return("env")
