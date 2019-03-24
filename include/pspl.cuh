
/* This part does nothing but to resolve mis-reported intellisense errors. */
#ifdef __INTELLISENSE__

#define __host__
#define __device__
#define atomicAdd
#define atomicSub
#define atomicExch
#define clock64() 0
#define __syncthreads()

#endif

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#include <stdio.h>
#include <math.h>
#include <string.h>
#include <memory.h>

#ifndef _PSPL_CUH
#define _PSPL_CUH

enum mark_t{ start, end };

enum h_matrix_t { empty, dense, low_rank, hierarchical };

enum dep_t { no_dep, flow_dep, anti_dep, flow_anti_dep, output_dep, flow_output_dep, anti_output_dep, flow_anti_output_dep };

enum matrix_op_t { nop, getrf, trsml, trsmr, gemm, pivot };

__device__ int thread_rank()
{ return (threadIdx.z * blockDim.y + threadIdx.y) * blockDim.x + threadIdx.x; }

__device__ int block_dim()
{ return blockDim.z * blockDim.y * blockDim.x; }

__device__ int block_rank()
{ return (blockIdx.z * gridDim.y + blockIdx.y) * gridDim.x + blockIdx.x; }

__device__ int grid_dim()
{ return gridDim.z * gridDim.y * gridDim.x; }

__device__ int warp_rank()
{ return thread_rank() / warpSize; }

__device__ int lane_rank()
{ return thread_rank() - warpSize * warp_rank(); }

#include <dev_dense.cuh>
#include <dev_dense_funcs.cuh>

#include <index.cuh>
#include <dev_low_rank.cuh>

template <class T> class dev_hierarchical;
template <class T> class h_matrix_element;

#include <dev_hierarchical.cuh>

#include <ops.cuh>
#include <get_ops.cuh>
#include <dag.cuh>
#include <inst_handler.cuh>

#include <timer.cuh>
#include <kernel.cuh>

#endif