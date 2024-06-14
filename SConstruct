#!/usr/bin/env python

import os
import platform
import sys
import subprocess
from SCons.Errors import UserError

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

platforms = ("macos", "windows")
opts.Add(
    EnumVariable(
        key="platform",
        help="Target platform",
        default=env.get("platform", default_platform),
        allowed_values=platforms,
        ignorecase=2,
    )
)

opts.Add(BoolVariable("use_asan", "Use address sanitizer (ASAN) in MSVC", False))

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

# Sanitizers.
if env.get("use_asan", False) and and env.get("is_msvc", False):
    env["extra_suffix"] = "san"
    env.Append(LINKFLAGS=["/INFERASANLIBS"])
    env.Append(CCFLAGS=["/fsanitize=address"])


scons_cache_path = os.environ.get("SCONS_CACHE")
if scons_cache_path is not None:
    CacheDir(scons_cache_path)
    Decider("MD5")

angle_sources = [
    "src/common/aligned_memory.cpp",
    "src/common/android_util.cpp",
    "src/common/angleutils.cpp",
    "src/common/angle_version_info.cpp",
    "src/common/CompiledShaderState.cpp",
    "src/common/debug.cpp",
    "src/common/entry_points_enum_autogen.cpp",
    "src/common/event_tracer.cpp",
    "src/common/Float16ToFloat32.cpp",
    "src/common/gl_enum_utils.cpp",
    "src/common/gl_enum_utils_autogen.cpp",
    "src/common/mathutil.cpp",
    "src/common/matrix_utils.cpp",
    "src/common/MemoryBuffer.cpp",
    "src/common/PackedCLEnums_autogen.cpp",
    "src/common/PackedEGLEnums_autogen.cpp",
    "src/common/PackedEnums.cpp",
    "src/common/PackedGLEnums_autogen.cpp",
    "src/common/platform_helpers.cpp",
    "src/common/PoolAlloc.cpp",
    "src/common/RingBufferAllocator.cpp",
    "src/common/string_utils.cpp",
    "src/common/system_utils.cpp",
    "src/common/tls.cpp",
    "src/common/uniform_type_info_autogen.cpp",
    "src/common/utilities.cpp",
    "src/common/WorkerThread.cpp",
    "src/common/base/anglebase/sha1.cc",
    "src/compiler/preprocessor/DiagnosticsBase.cpp",
    "src/compiler/preprocessor/DirectiveHandlerBase.cpp",
    "src/compiler/preprocessor/DirectiveParser.cpp",
    "src/compiler/preprocessor/Input.cpp",
    "src/compiler/preprocessor/Lexer.cpp",
    "src/compiler/preprocessor/Macro.cpp",
    "src/compiler/preprocessor/MacroExpander.cpp",
    "src/compiler/preprocessor/Preprocessor.cpp",
    "src/compiler/preprocessor/preprocessor_lex_autogen.cpp",
    "src/compiler/preprocessor/preprocessor_tab_autogen.cpp",
    "src/compiler/preprocessor/Token.cpp",
    "src/compiler/translator/BaseTypes.cpp",
    "src/compiler/translator/blocklayout.cpp",
    "src/compiler/translator/BuiltInFunctionEmulator.cpp",
    "src/compiler/translator/CallDAG.cpp",
    "src/compiler/translator/CodeGen.cpp",
    "src/compiler/translator/CollectVariables.cpp",
    "src/compiler/translator/Compiler.cpp",
    "src/compiler/translator/ConstantUnion.cpp",
    "src/compiler/translator/Declarator.cpp",
    "src/compiler/translator/Diagnostics.cpp",
    "src/compiler/translator/DirectiveHandler.cpp",
    "src/compiler/translator/ExtensionBehavior.cpp",
    "src/compiler/translator/FlagStd140Structs.cpp",
    "src/compiler/translator/FunctionLookup.cpp",
    "src/compiler/translator/glslang_lex_autogen.cpp",
    "src/compiler/translator/glslang_tab_autogen.cpp",
    "src/compiler/translator/HashNames.cpp",
    "src/compiler/translator/ImmutableStringBuilder.cpp",
    "src/compiler/translator/ImmutableString_ESSL_autogen.cpp",
    "src/compiler/translator/InfoSink.cpp",
    "src/compiler/translator/Initialize.cpp",
    "src/compiler/translator/InitializeDll.cpp",
    "src/compiler/translator/IntermNode.cpp",
    "src/compiler/translator/IsASTDepthBelowLimit.cpp",
    "src/compiler/translator/Operator.cpp",
    "src/compiler/translator/OutputTree.cpp",
    "src/compiler/translator/ParseContext.cpp",
    "src/compiler/translator/PoolAlloc.cpp",
    "src/compiler/translator/QualifierTypes.cpp",
    "src/compiler/translator/ShaderLang.cpp",
    "src/compiler/translator/ShaderVars.cpp",
    "src/compiler/translator/Symbol.cpp",
    "src/compiler/translator/SymbolTable.cpp",
    "src/compiler/translator/SymbolTable_ESSL_autogen.cpp",
    "src/compiler/translator/SymbolUniqueId.cpp",
    "src/compiler/translator/Types.cpp",
    "src/compiler/translator/util.cpp",
    "src/compiler/translator/ValidateAST.cpp",
    "src/compiler/translator/ValidateBarrierFunctionCall.cpp",
    "src/compiler/translator/ValidateClipCullDistance.cpp",
    "src/compiler/translator/ValidateGlobalInitializer.cpp",
    "src/compiler/translator/ValidateLimitations.cpp",
    "src/compiler/translator/ValidateMaxParameters.cpp",
    "src/compiler/translator/ValidateOutputs.cpp",
    "src/compiler/translator/ValidateSwitch.cpp",
    "src/compiler/translator/ValidateTypeSizeLimitations.cpp",
    "src/compiler/translator/ValidateVaryingLocations.cpp",
    "src/compiler/translator/VariablePacker.cpp",
    "src/compiler/translator/glsl/BuiltInFunctionEmulatorGLSL.cpp",
    "src/compiler/translator/glsl/ExtensionGLSL.cpp",
    "src/compiler/translator/glsl/OutputESSL.cpp",
    "src/compiler/translator/glsl/OutputGLSL.cpp",
    "src/compiler/translator/glsl/OutputGLSLBase.cpp",
    "src/compiler/translator/glsl/TranslatorESSL.cpp",
    "src/compiler/translator/glsl/TranslatorGLSL.cpp",
    "src/compiler/translator/glsl/VersionGLSL.cpp",
    "src/compiler/translator/tree_ops/ClampFragDepth.cpp",
    "src/compiler/translator/tree_ops/ClampIndirectIndices.cpp",
    "src/compiler/translator/tree_ops/ClampPointSize.cpp",
    "src/compiler/translator/tree_ops/DeclareAndInitBuiltinsForInstancedMultiview.cpp",
    "src/compiler/translator/tree_ops/DeclarePerVertexBlocks.cpp",
    "src/compiler/translator/tree_ops/DeferGlobalInitializers.cpp",
    "src/compiler/translator/tree_ops/EmulateGLFragColorBroadcast.cpp",
    "src/compiler/translator/tree_ops/EmulateMultiDrawShaderBuiltins.cpp",
    "src/compiler/translator/tree_ops/FoldExpressions.cpp",
    "src/compiler/translator/tree_ops/ForcePrecisionQualifier.cpp",
    "src/compiler/translator/tree_ops/InitializeVariables.cpp",
    "src/compiler/translator/tree_ops/MonomorphizeUnsupportedFunctions.cpp",
    "src/compiler/translator/tree_ops/PruneEmptyCases.cpp",
    "src/compiler/translator/tree_ops/PruneNoOps.cpp",
    "src/compiler/translator/tree_ops/RecordConstantPrecision.cpp",
    "src/compiler/translator/tree_ops/RemoveArrayLengthMethod.cpp",
    "src/compiler/translator/tree_ops/RemoveAtomicCounterBuiltins.cpp",
    "src/compiler/translator/tree_ops/RemoveDynamicIndexing.cpp",
    "src/compiler/translator/tree_ops/RemoveInactiveInterfaceVariables.cpp",
    "src/compiler/translator/tree_ops/RemoveInvariantDeclaration.cpp",
    "src/compiler/translator/tree_ops/RemoveUnreferencedVariables.cpp",
    "src/compiler/translator/tree_ops/RewriteArrayOfArrayOfOpaqueUniforms.cpp",
    "src/compiler/translator/tree_ops/RewriteAtomicCounters.cpp",
    "src/compiler/translator/tree_ops/RewriteCubeMapSamplersAs2DArray.cpp",
    "src/compiler/translator/tree_ops/RewriteDfdy.cpp",
    "src/compiler/translator/tree_ops/RewritePixelLocalStorage.cpp",
    "src/compiler/translator/tree_ops/RewriteStructSamplers.cpp",
    "src/compiler/translator/tree_ops/RewriteTexelFetchOffset.cpp",
    "src/compiler/translator/tree_ops/SeparateDeclarations.cpp",
    "src/compiler/translator/tree_ops/SeparateStructFromUniformDeclarations.cpp",
    "src/compiler/translator/tree_ops/SimplifyLoopConditions.cpp",
    "src/compiler/translator/tree_ops/SplitSequenceOperator.cpp",
    "src/compiler/translator/tree_ops/glsl/RegenerateStructNames.cpp",
    "src/compiler/translator/tree_ops/glsl/RewriteRepeatedAssignToSwizzled.cpp",
    "src/compiler/translator/tree_ops/glsl/ScalarizeVecAndMatConstructorArgs.cpp",
    "src/compiler/translator/tree_ops/glsl/UseInterfaceBlockFields.cpp",
    "src/compiler/translator/tree_util/DriverUniform.cpp",
    "src/compiler/translator/tree_util/FindFunction.cpp",
    "src/compiler/translator/tree_util/FindMain.cpp",
    "src/compiler/translator/tree_util/FindPreciseNodes.cpp",
    "src/compiler/translator/tree_util/FindSymbolNode.cpp",
    "src/compiler/translator/tree_util/IntermNodePatternMatcher.cpp",
    "src/compiler/translator/tree_util/IntermNode_util.cpp",
    "src/compiler/translator/tree_util/IntermTraverse.cpp",
    "src/compiler/translator/tree_util/ReplaceArrayOfMatrixVarying.cpp",
    "src/compiler/translator/tree_util/ReplaceClipCullDistanceVariable.cpp",
    "src/compiler/translator/tree_util/ReplaceShadowingVariables.cpp",
    "src/compiler/translator/tree_util/ReplaceVariable.cpp",
    "src/compiler/translator/tree_util/RewriteSampleMaskVariable.cpp",
    "src/compiler/translator/tree_util/RunAtTheBeginningOfShader.cpp",
    "src/compiler/translator/tree_util/RunAtTheEndOfShader.cpp",
    "src/compiler/translator/tree_util/SpecializationConstant.cpp",
    "src/gpu_info_util/SystemInfo.cpp",
    "src/libANGLE/angletypes.cpp",
    "src/libANGLE/AttributeMap.cpp",
    "src/libANGLE/BlobCache.cpp",
    "src/libANGLE/Buffer.cpp",
    "src/libANGLE/Caps.cpp",
    "src/libANGLE/CLBuffer.cpp",
    "src/libANGLE/CLCommandQueue.cpp",
    "src/libANGLE/CLContext.cpp",
    "src/libANGLE/CLDevice.cpp",
    "src/libANGLE/CLEvent.cpp",
    "src/libANGLE/CLImage.cpp",
    "src/libANGLE/CLKernel.cpp",
    "src/libANGLE/CLMemory.cpp",
    "src/libANGLE/CLObject.cpp",
    "src/libANGLE/CLPlatform.cpp",
    "src/libANGLE/CLProgram.cpp",
    "src/libANGLE/CLSampler.cpp",
    "src/libANGLE/cl_utils.cpp",
    "src/libANGLE/Compiler.cpp",
    "src/libANGLE/Config.cpp",
    "src/libANGLE/Context.cpp",
    "src/libANGLE/Context_gl.cpp",
    "src/libANGLE/Context_gles_1_0.cpp",
    "src/libANGLE/context_private_call_gl.cpp",
    "src/libANGLE/context_private_call_gles.cpp",
    "src/libANGLE/Debug.cpp",
    "src/libANGLE/Device.cpp",
    "src/libANGLE/Display.cpp",
    "src/libANGLE/EGLSync.cpp",
    "src/libANGLE/entry_points_utils.cpp",
    "src/libANGLE/Error.cpp",
    "src/libANGLE/es3_copy_conversion_table_autogen.cpp",
    "src/libANGLE/Fence.cpp",
    "src/libANGLE/formatutils.cpp",
    "src/libANGLE/format_map_autogen.cpp",
    "src/libANGLE/format_map_desktop.cpp",
    "src/libANGLE/Framebuffer.cpp",
    "src/libANGLE/FramebufferAttachment.cpp",
    "src/libANGLE/GLES1Renderer.cpp",
    "src/libANGLE/GLES1State.cpp",
    "src/libANGLE/gles_extensions_autogen.cpp",
    "src/libANGLE/GlobalMutex.cpp",
    "src/libANGLE/HandleAllocator.cpp",
    "src/libANGLE/Image.cpp",
    "src/libANGLE/ImageIndex.cpp",
    "src/libANGLE/IndexRangeCache.cpp",
    "src/libANGLE/LoggingAnnotator.cpp",
    "src/libANGLE/MemoryObject.cpp",
    "src/libANGLE/MemoryProgramCache.cpp",
    "src/libANGLE/MemoryShaderCache.cpp",
    "src/libANGLE/Observer.cpp",
    "src/libANGLE/Overlay.cpp",
    "src/libANGLE/OverlayWidgets.cpp",
    "src/libANGLE/Overlay_autogen.cpp",
    "src/libANGLE/Overlay_font_autogen.cpp",
    "src/libANGLE/PixelLocalStorage.cpp",
    "src/libANGLE/Platform.cpp",
    "src/libANGLE/Program.cpp",
    "src/libANGLE/ProgramExecutable.cpp",
    "src/libANGLE/ProgramLinkedResources.cpp",
    "src/libANGLE/ProgramPipeline.cpp",
    "src/libANGLE/Query.cpp",
    "src/libANGLE/queryconversions.cpp",
    "src/libANGLE/queryutils.cpp",
    "src/libANGLE/Renderbuffer.cpp",
    "src/libANGLE/ResourceManager.cpp",
    "src/libANGLE/Sampler.cpp",
    "src/libANGLE/Semaphore.cpp",
    "src/libANGLE/Shader.cpp",
    "src/libANGLE/SharedContextMutex.cpp",
    "src/libANGLE/ShareGroup.cpp",
    "src/libANGLE/State.cpp",
    "src/libANGLE/Stream.cpp",
    "src/libANGLE/Surface.cpp",
    "src/libANGLE/Texture.cpp",
    "src/libANGLE/Thread.cpp",
    "src/libANGLE/TransformFeedback.cpp",
    "src/libANGLE/Uniform.cpp",
    "src/libANGLE/validationCL.cpp",
    "src/libANGLE/validationEGL.cpp",
    "src/libANGLE/validationES.cpp",
    "src/libANGLE/validationES1.cpp",
    "src/libANGLE/validationES2.cpp",
    "src/libANGLE/validationES3.cpp",
    "src/libANGLE/validationES31.cpp",
    "src/libANGLE/validationES32.cpp",
    "src/libANGLE/validationESEXT.cpp",
    "src/libANGLE/validationGL1.cpp",
    "src/libANGLE/validationGL2.cpp",
    "src/libANGLE/validationGL3.cpp",
    "src/libANGLE/validationGL4.cpp",
    "src/libANGLE/VaryingPacking.cpp",
    "src/libANGLE/VertexArray.cpp",
    "src/libANGLE/VertexAttribute.cpp",
    "src/libANGLE/capture/FrameCapture_mock.cpp",
    "src/libANGLE/capture/serialize_mock.cpp",
    "src/libANGLE/renderer/BufferImpl.cpp",
    "src/libANGLE/renderer/CLCommandQueueImpl.cpp",
    "src/libANGLE/renderer/CLContextImpl.cpp",
    "src/libANGLE/renderer/CLDeviceImpl.cpp",
    "src/libANGLE/renderer/CLEventImpl.cpp",
    "src/libANGLE/renderer/CLExtensions.cpp",
    "src/libANGLE/renderer/CLKernelImpl.cpp",
    "src/libANGLE/renderer/CLMemoryImpl.cpp",
    "src/libANGLE/renderer/CLPlatformImpl.cpp",
    "src/libANGLE/renderer/CLProgramImpl.cpp",
    "src/libANGLE/renderer/CLSamplerImpl.cpp",
    "src/libANGLE/renderer/ContextImpl.cpp",
    "src/libANGLE/renderer/DeviceImpl.cpp",
    "src/libANGLE/renderer/DisplayImpl.cpp",
    "src/libANGLE/renderer/driver_utils.cpp",
    "src/libANGLE/renderer/EGLReusableSync.cpp",
    "src/libANGLE/renderer/EGLSyncImpl.cpp",
    "src/libANGLE/renderer/Format_table_autogen.cpp",
    "src/libANGLE/renderer/FramebufferImpl.cpp",
    "src/libANGLE/renderer/ImageImpl.cpp",
    "src/libANGLE/renderer/load_functions_table_autogen.cpp",
    "src/libANGLE/renderer/ProgramImpl.cpp",
    "src/libANGLE/renderer/ProgramPipelineImpl.cpp",
    "src/libANGLE/renderer/QueryImpl.cpp",
    "src/libANGLE/renderer/RenderbufferImpl.cpp",
    "src/libANGLE/renderer/renderer_utils.cpp",
    "src/libANGLE/renderer/ShaderImpl.cpp",
    "src/libANGLE/renderer/SurfaceImpl.cpp",
    "src/libANGLE/renderer/TextureImpl.cpp",
    "src/libANGLE/renderer/TransformFeedbackImpl.cpp",
    "src/libANGLE/renderer/VertexArrayImpl.cpp",
    "src/image_util/AstcDecompressor.cpp",
    "src/image_util/copyimage.cpp",
    "src/image_util/imageformats.cpp",
    "src/image_util/loadimage.cpp",
    "src/image_util/loadimage_astc.cpp",
    "src/image_util/loadimage_etc.cpp",
    "src/image_util/loadimage_paletted.cpp",
    "src/image_util/storeimage_paletted.cpp",
    "src/common/third_party/xxhash/xxhash.c",
    "third_party/zlib/google/compression_utils_portable.cc",
    "third_party/zlib/adler32.c",
    "third_party/zlib/compress.c",
    "third_party/zlib/cpu_features.c",
    "third_party/zlib/crc32.c",
    "third_party/zlib/crc_folding.c",
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
    "third_party/astc-encoder/src/Source/astcenc_averages_and_directions.cpp",
    "third_party/astc-encoder/src/Source/astcenc_block_sizes.cpp",
    "third_party/astc-encoder/src/Source/astcenc_color_quantize.cpp",
    "third_party/astc-encoder/src/Source/astcenc_color_unquantize.cpp",
    "third_party/astc-encoder/src/Source/astcenc_compress_symbolic.cpp",
    "third_party/astc-encoder/src/Source/astcenc_compute_variance.cpp",
    "third_party/astc-encoder/src/Source/astcenc_decompress_symbolic.cpp",
    "third_party/astc-encoder/src/Source/astcenc_diagnostic_trace.cpp",
    "third_party/astc-encoder/src/Source/astcenc_entry.cpp",
    "third_party/astc-encoder/src/Source/astcenc_find_best_partitioning.cpp",
    "third_party/astc-encoder/src/Source/astcenc_ideal_endpoints_and_weights.cpp",
    "third_party/astc-encoder/src/Source/astcenc_image.cpp",
    "third_party/astc-encoder/src/Source/astcenc_integer_sequence.cpp",
    "third_party/astc-encoder/src/Source/astcenc_mathlib.cpp",
    "third_party/astc-encoder/src/Source/astcenc_mathlib_softfloat.cpp",
    "third_party/astc-encoder/src/Source/astcenc_partition_tables.cpp",
    "third_party/astc-encoder/src/Source/astcenc_percentile_tables.cpp",
    "third_party/astc-encoder/src/Source/astcenc_pick_best_endpoint_format.cpp",
    "third_party/astc-encoder/src/Source/astcenc_platform_isa_detection.cpp",
    "third_party/astc-encoder/src/Source/astcenc_quantization.cpp",
    "third_party/astc-encoder/src/Source/astcenc_symbolic_physical.cpp",
    "third_party/astc-encoder/src/Source/astcenc_weight_align.cpp",
    "third_party/astc-encoder/src/Source/astcenc_weight_quant_xfer_tables.cpp",
]
if env["platform"] == "macos":
    angle_sources += [
        "src/common/apple_platform_utils.mm",
        "src/common/system_utils_apple.cpp",
        "src/common/system_utils_posix.cpp",
        "src/common/system_utils_mac.cpp",
        "src/common/gl/cgl/FunctionsCGL.cpp",
        "src/compiler/translator/msl/AstHelpers.cpp",
        "src/compiler/translator/msl/ConstantNames.cpp",
        "src/compiler/translator/msl/DiscoverDependentFunctions.cpp",
        "src/compiler/translator/msl/DiscoverEnclosingFunctionTraverser.cpp",
        "src/compiler/translator/msl/DriverUniformMetal.cpp",
        "src/compiler/translator/msl/EmitMetal.cpp",
        "src/compiler/translator/msl/IdGen.cpp",
        "src/compiler/translator/msl/IntermRebuild.cpp",
        "src/compiler/translator/msl/Layout.cpp",
        "src/compiler/translator/msl/MapFunctionsToDefinitions.cpp",
        "src/compiler/translator/msl/MapSymbols.cpp",
        "src/compiler/translator/msl/ModifyStruct.cpp",
        "src/compiler/translator/msl/Name.cpp",
        "src/compiler/translator/msl/Pipeline.cpp",
        "src/compiler/translator/msl/ProgramPrelude.cpp",
        "src/compiler/translator/msl/RewritePipelines.cpp",
        "src/compiler/translator/msl/SymbolEnv.cpp",
        "src/compiler/translator/msl/ToposortStructs.cpp",
        "src/compiler/translator/msl/TranslatorMSL.cpp",
        "src/compiler/translator/msl/UtilsMSL.cpp",
        "src/compiler/translator/tree_ops/glsl/apple/AddAndTrueToLoopCondition.cpp",
        "src/compiler/translator/tree_ops/glsl/apple/RewriteDoWhile.cpp",
        "src/compiler/translator/tree_ops/glsl/apple/RewriteRowMajorMatrices.cpp",
        "src/compiler/translator/tree_ops/glsl/apple/RewriteUnaryMinusOperatorFloat.cpp",
        "src/compiler/translator/tree_ops/glsl/apple/UnfoldShortCircuitAST.cpp",
        "src/compiler/translator/tree_ops/msl/AddExplicitTypeCasts.cpp",
        "src/compiler/translator/tree_ops/msl/ConvertUnsupportedConstructorsToFunctionCalls.cpp",
        "src/compiler/translator/tree_ops/msl/FixTypeConstructors.cpp",
        "src/compiler/translator/tree_ops/msl/GuardFragDepthWrite.cpp",
        "src/compiler/translator/tree_ops/msl/HoistConstants.cpp",
        "src/compiler/translator/tree_ops/msl/IntroduceVertexIndexID.cpp",
        "src/compiler/translator/tree_ops/msl/NameEmbeddedUniformStructsMetal.cpp",
        "src/compiler/translator/tree_ops/msl/ReduceInterfaceBlocks.cpp",
        "src/compiler/translator/tree_ops/msl/RewriteCaseDeclarations.cpp",
        "src/compiler/translator/tree_ops/msl/RewriteInterpolants.cpp",
        "src/compiler/translator/tree_ops/msl/RewriteOutArgs.cpp",
        "src/compiler/translator/tree_ops/msl/RewriteUnaddressableReferences.cpp",
        "src/compiler/translator/tree_ops/msl/SeparateCompoundExpressions.cpp",
        "src/compiler/translator/tree_ops/msl/SeparateCompoundStructDeclarations.cpp",
        "src/compiler/translator/tree_ops/msl/TransposeRowMajorMatrices.cpp",
        "src/compiler/translator/tree_ops/msl/WrapMain.cpp",
        "src/gpu_info_util/SystemInfo_apple.mm",
        "src/gpu_info_util/SystemInfo_macos.mm",
        "src/libANGLE/renderer/driver_utils_mac.mm",
        "src/libANGLE/renderer/metal/BufferMtl.mm",
        "src/libANGLE/renderer/metal/CompilerMtl.mm",
        "src/libANGLE/renderer/metal/ContextMtl.mm",
        "src/libANGLE/renderer/metal/DeviceMtl.mm",
        "src/libANGLE/renderer/metal/DisplayMtl.mm",
        "src/libANGLE/renderer/metal/FrameBufferMtl.mm",
        "src/libANGLE/renderer/metal/IOSurfaceSurfaceMtl.mm",
        "src/libANGLE/renderer/metal/ImageMtl.mm",
        "src/libANGLE/renderer/metal/ProgramMtl.mm",
        "src/libANGLE/renderer/metal/ProvokingVertexHelper.mm",
        "src/libANGLE/renderer/metal/QueryMtl.mm",
        "src/libANGLE/renderer/metal/RenderBufferMtl.mm",
        "src/libANGLE/renderer/metal/RenderTargetMtl.mm",
        "src/libANGLE/renderer/metal/SamplerMtl.mm",
        "src/libANGLE/renderer/metal/ShaderMtl.mm",
        "src/libANGLE/renderer/metal/SurfaceMtl.mm",
        "src/libANGLE/renderer/metal/SyncMtl.mm",
        "src/libANGLE/renderer/metal/TextureMtl.mm",
        "src/libANGLE/renderer/metal/TransformFeedbackMtl.mm",
        "src/libANGLE/renderer/metal/VertexArrayMtl.mm",
        "src/libANGLE/renderer/metal/blocklayoutMetal.cpp",
        "src/libANGLE/renderer/metal/mtl_buffer_manager.mm",
        "src/libANGLE/renderer/metal/mtl_buffer_pool.mm",
        "src/libANGLE/renderer/metal/mtl_command_buffer.mm",
        "src/libANGLE/renderer/metal/mtl_common.mm",
        "src/libANGLE/renderer/metal/mtl_context_device.mm",
        "src/libANGLE/renderer/metal/mtl_format_table_autogen.mm",
        "src/libANGLE/renderer/metal/mtl_format_utils.mm",
        "src/libANGLE/renderer/metal/mtl_library_cache.mm",
        "src/libANGLE/renderer/metal/mtl_msl_utils.mm",
        "src/libANGLE/renderer/metal/mtl_occlusion_query_pool.mm",
        "src/libANGLE/renderer/metal/mtl_pipeline_cache.mm",
        "src/libANGLE/renderer/metal/mtl_render_utils.mm",
        "src/libANGLE/renderer/metal/mtl_resources.mm",
        "src/libANGLE/renderer/metal/mtl_state_cache.mm",
        "src/libANGLE/renderer/metal/mtl_utils.mm",
        "src/libANGLE/renderer/metal/process.cpp",
        "src/libANGLE/renderer/metal/renderermtl_utils.cpp",
        "src/libANGLE/renderer/gl/BlitGL.cpp",
        "src/libANGLE/renderer/gl/DisplayGL.cpp",
        "src/libANGLE/renderer/gl/MemoryObjectGL.cpp",
        "src/libANGLE/renderer/gl/RendererGL.cpp",
        "src/libANGLE/renderer/gl/SyncGL.cpp",
        "src/libANGLE/renderer/gl/renderergl_utils.cpp",
        "src/libANGLE/renderer/gl/BufferGL.cpp",
        "src/libANGLE/renderer/gl/PLSProgramCache.cpp",
        "src/libANGLE/renderer/gl/SamplerGL.cpp",
        "src/libANGLE/renderer/gl/TextureGL.cpp",
        "src/libANGLE/renderer/gl/ClearMultiviewGL.cpp",
        "src/libANGLE/renderer/gl/FenceNVGL.cpp",
        "src/libANGLE/renderer/gl/ProgramGL.cpp",
        "src/libANGLE/renderer/gl/SemaphoreGL.cpp",
        "src/libANGLE/renderer/gl/TransformFeedbackGL.cpp",
        "src/libANGLE/renderer/gl/CompilerGL.cpp",
        "src/libANGLE/renderer/gl/FramebufferGL.cpp",
        "src/libANGLE/renderer/gl/ProgramPipelineGL.cpp",
        "src/libANGLE/renderer/gl/ShaderGL.cpp",
        "src/libANGLE/renderer/gl/VertexArrayGL.cpp",
        "src/libANGLE/renderer/gl/ContextGL.cpp",
        "src/libANGLE/renderer/gl/FunctionsGL.cpp",
        "src/libANGLE/renderer/gl/QueryGL.cpp",
        "src/libANGLE/renderer/gl/StateManagerGL.cpp",
        "src/libANGLE/renderer/gl/formatutilsgl.cpp",
        "src/libANGLE/renderer/gl/DispatchTableGL_autogen.cpp",
        "src/libANGLE/renderer/gl/ImageGL.cpp",
        "src/libANGLE/renderer/gl/RenderbufferGL.cpp",
        "src/libANGLE/renderer/gl/SurfaceGL.cpp",
        "src/libANGLE/renderer/gl/null_functions.cpp",
        "src/libANGLE/renderer/gl/cgl/ContextCGL.cpp",
        "src/libANGLE/renderer/gl/cgl/DisplayCGL.mm",
        "src/libANGLE/renderer/gl/cgl/DeviceCGL.cpp",
        "src/libANGLE/renderer/gl/cgl/IOSurfaceSurfaceCGL.cpp",
        "src/libANGLE/renderer/gl/cgl/PbufferSurfaceCGL.cpp",
        "src/libANGLE/renderer/gl/cgl/RendererCGL.cpp",
        "src/libANGLE/renderer/gl/cgl/WindowSurfaceCGL.mm",
    ]
if env["platform"] == "windows":
    angle_sources += [
        "src/common/system_utils_win.cpp",
        "src/common/system_utils_win32.cpp",
        "src/compiler/translator/hlsl/ASTMetadataHLSL.cpp",
        "src/compiler/translator/hlsl/AtomicCounterFunctionHLSL.cpp",
        "src/compiler/translator/hlsl/blocklayoutHLSL.cpp",
        "src/compiler/translator/hlsl/BuiltInFunctionEmulatorHLSL.cpp",
        "src/compiler/translator/hlsl/emulated_builtin_functions_hlsl_autogen.cpp",
        "src/compiler/translator/hlsl/ImageFunctionHLSL.cpp",
        "src/compiler/translator/hlsl/OutputHLSL.cpp",
        "src/compiler/translator/hlsl/ResourcesHLSL.cpp",
        "src/compiler/translator/hlsl/ShaderStorageBlockFunctionHLSL.cpp",
        "src/compiler/translator/hlsl/ShaderStorageBlockOutputHLSL.cpp",
        "src/compiler/translator/hlsl/StructureHLSL.cpp",
        "src/compiler/translator/hlsl/TextureFunctionHLSL.cpp",
        "src/compiler/translator/hlsl/TranslatorHLSL.cpp",
        "src/compiler/translator/hlsl/UtilsHLSL.cpp",
        "src/compiler/translator/tree_ops/hlsl/AddDefaultReturnStatements.cpp",
        "src/compiler/translator/tree_ops/hlsl/AggregateAssignArraysInSSBOs.cpp",
        "src/compiler/translator/tree_ops/hlsl/AggregateAssignStructsInSSBOs.cpp",
        "src/compiler/translator/tree_ops/hlsl/ArrayReturnValueToOutParameter.cpp",
        "src/compiler/translator/tree_ops/hlsl/BreakVariableAliasingInInnerLoops.cpp",
        "src/compiler/translator/tree_ops/hlsl/ExpandIntegerPowExpressions.cpp",
        "src/compiler/translator/tree_ops/hlsl/RecordUniformBlocksWithLargeArrayMember.cpp",
        "src/compiler/translator/tree_ops/hlsl/RemoveSwitchFallThrough.cpp",
        "src/compiler/translator/tree_ops/hlsl/RewriteAtomicFunctionExpressions.cpp",
        "src/compiler/translator/tree_ops/hlsl/RewriteElseBlocks.cpp",
        "src/compiler/translator/tree_ops/hlsl/RewriteExpressionsWithShaderStorageBlock.cpp",
        "src/compiler/translator/tree_ops/hlsl/RewriteUnaryMinusOperatorInt.cpp",
        "src/compiler/translator/tree_ops/hlsl/SeparateArrayConstructorStatements.cpp",
        "src/compiler/translator/tree_ops/hlsl/SeparateArrayInitialization.cpp",
        "src/compiler/translator/tree_ops/hlsl/SeparateExpressionsReturningArrays.cpp",
        "src/compiler/translator/tree_ops/hlsl/UnfoldShortCircuitToIf.cpp",
        "src/compiler/translator/tree_ops/hlsl/WrapSwitchStatementsInBlocks.cpp",
        "src/gpu_info_util/SystemInfo_win.cpp",
        "src/libANGLE/renderer/d3d_format.cpp",
        "src/libANGLE/renderer/dxgi_format_map_autogen.cpp",
        "src/libANGLE/renderer/dxgi_support_table_autogen.cpp",
        "src/libANGLE/renderer/d3d/BufferD3D.cpp",
        "src/libANGLE/renderer/d3d/CompilerD3D.cpp",
        "src/libANGLE/renderer/d3d/DeviceD3D.cpp",
        "src/libANGLE/renderer/d3d/DisplayD3D.cpp",
        "src/libANGLE/renderer/d3d/driver_utils_d3d.cpp",
        "src/libANGLE/renderer/d3d/DynamicHLSL.cpp",
        "src/libANGLE/renderer/d3d/DynamicImage2DHLSL.cpp",
        "src/libANGLE/renderer/d3d/EGLImageD3D.cpp",
        "src/libANGLE/renderer/d3d/FramebufferD3D.cpp",
        "src/libANGLE/renderer/d3d/HLSLCompiler.cpp",
        "src/libANGLE/renderer/d3d/ImageD3D.cpp",
        "src/libANGLE/renderer/d3d/IndexBuffer.cpp",
        "src/libANGLE/renderer/d3d/IndexDataManager.cpp",
        "src/libANGLE/renderer/d3d/NativeWindowD3D.cpp",
        "src/libANGLE/renderer/d3d/ProgramD3D.cpp",
        "src/libANGLE/renderer/d3d/RenderbufferD3D.cpp",
        "src/libANGLE/renderer/d3d/RendererD3D.cpp",
        "src/libANGLE/renderer/d3d/RenderTargetD3D.cpp",
        "src/libANGLE/renderer/d3d/ShaderD3D.cpp",
        "src/libANGLE/renderer/d3d/ShaderExecutableD3D.cpp",
        "src/libANGLE/renderer/d3d/SurfaceD3D.cpp",
        "src/libANGLE/renderer/d3d/SwapChainD3D.cpp",
        "src/libANGLE/renderer/d3d/TextureD3D.cpp",
        "src/libANGLE/renderer/d3d/VertexBuffer.cpp",
        "src/libANGLE/renderer/d3d/VertexDataManager.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Blit11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Buffer11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Clear11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Context11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/DebugAnnotator11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/ExternalImageSiblingImpl11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Fence11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/formatutils11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Framebuffer11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Image11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/IndexBuffer11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/InputLayoutCache.cpp",
        "src/libANGLE/renderer/d3d/d3d11/MappedSubresourceVerifier11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/PixelTransfer11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Program11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/ProgramPipeline11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Query11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Renderer11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/renderer11_utils.cpp",
        "src/libANGLE/renderer/d3d/d3d11/RenderStateCache.cpp",
        "src/libANGLE/renderer/d3d/d3d11/RenderTarget11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/ResourceManager11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/ShaderExecutable11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/StateManager11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/StreamProducerD3DTexture.cpp",
        "src/libANGLE/renderer/d3d/d3d11/SwapChain11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/TextureStorage11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/texture_format_table.cpp",
        "src/libANGLE/renderer/d3d/d3d11/texture_format_table_autogen.cpp",
        "src/libANGLE/renderer/d3d/d3d11/TransformFeedback11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/Trim11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/VertexArray11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/VertexBuffer11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/converged/CompositorNativeWindow11.cpp",
        "src/libANGLE/renderer/d3d/d3d11/win32/NativeWindow11Win32.cpp",
    ]
angle_sources_egl = [
    "src/libEGL/egl_loader_autogen.cpp",
    "src/libEGL/libEGL_autogen.cpp",
]
angle_sources_gles = [
    "src/libGLESv2/egl_ext_stubs.cpp",
    "src/libGLESv2/egl_stubs.cpp",
    "src/libGLESv2/entry_points_egl_autogen.cpp",
    "src/libGLESv2/entry_points_egl_ext_autogen.cpp",
    "src/libGLESv2/entry_points_gles_1_0_autogen.cpp",
    "src/libGLESv2/entry_points_gles_2_0_autogen.cpp",
    "src/libGLESv2/entry_points_gles_3_0_autogen.cpp",
    "src/libGLESv2/entry_points_gles_3_1_autogen.cpp",
    "src/libGLESv2/entry_points_gles_3_2_autogen.cpp",
    "src/libGLESv2/entry_points_gles_ext_autogen.cpp",
    "src/libGLESv2/global_state.cpp",
    "src/libGLESv2/libGLESv2_autogen.cpp",
    "src/libGLESv2/proc_table_egl_autogen.cpp",
]
env.Append(CPPDEFINES=[("ANGLE_CAPTURE_ENABLED", 0)])
env.Append(CPPDEFINES=[("ANGLE_ENABLE_ESSL", 1)])
env.Append(CPPDEFINES=[("ANGLE_ENABLE_GLSL", 1)])
env.Append(CPPDEFINES=[("ANGLE_EXPORT", '""')])
if env["arch"] in ["x86_64", "arm64"]:
    env.Append(CPPDEFINES=[("ANGLE_IS_64_BIT_CPU", 1)])
else:
    env.Append(CPPDEFINES=[("ANGLE_IS_32_BIT_CPU", 1)])
if env["platform"] == "macos":
    env.Append(CPPDEFINES=[("ANGLE_IS_MAC", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_METAL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_OPENGL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_GL_DESKTOP_BACKEND", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_GL_NULL", 1)])
    env.Append(CPPDEFINES=[("ANGLE_ENABLE_CGL", 1)])
    env.Append(CCFLAGS=["-fno-objc-arc", "-fno-objc-msgsend-selector-stubs", "-Wno-unused-command-line-argument"])
if env["platform"] == "windows":
    env.Append(CPPDEFINES=[("ANGLE_IS_WIN", 1)])
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

env.Append(CPPDEFINES=[("ANGLE_STANDALONE_BUILD", 1)])
env.Append(CPPDEFINES=[("ANGLE_STATIC", 1)])
env.Append(CPPDEFINES=[("ANGLE_UTIL_EXPORT", '""')])
env.Append(CPPDEFINES=[("EGLAPI", '""')])
env.Append(CPPDEFINES=[("GL_API", '""')])
env.Append(CPPDEFINES=[("GL_APICALL", '""')])
env.Append(CPPDEFINES=[("GL_SILENCE_DEPRECATION", 1)])

env.Prepend(CPPPATH=["src"])
env.Prepend(CPPPATH=["include"])
env.Prepend(CPPPATH=["include/KHR"])
env.Prepend(CPPPATH=["src/common/third_party/base"])
env.Prepend(CPPPATH=["src/common/base"])
env.Prepend(CPPPATH=["src/common/third_party/xxhash"])
env.Prepend(CPPPATH=["src/third_party/khronos"])
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

suffix = ".{}.{}".format(env["platform"], env["arch"])

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
