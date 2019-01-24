#ifndef PIVOT_CUH
#define PIVOT_CUH

#include <helper_functions.h>
#include <cuda_helper_functions.cuh>
#include <cooperative_groups.h>

using namespace cooperative_groups;

template <class matrixEntriesT, unsigned int tile_size>
__device__ unsigned int blockAllFindRowPivot (const unsigned int row, matrixEntriesT *matrix, const unsigned int nx, const unsigned int ld, const unsigned int ny)
{
  /*
  * Using 1 block, generates 1 row permutation for the input row.
  * Does not do row exchange, call another function to do that.
  * Output (for all threads) is the row number where matrix[output_row][row] has the largest absolute value.
  *
  * This is using tile_size as a template to control shared memory. Typically it should be warpSize 32.
  * But when shared memory is not enough, tile_size can be made smaller. 
  * The total amount of allocated shared memory is tile_size * size per entry.
  *
  * There is no limitations on the input matrix size, except that ld, the horizontal offset, needs to be not less than nx.
  */

  thread_block g = this_thread_block();
  thread_block_tile<tile_size> tile = tiled_partition<tile_size>(g);

  const unsigned int tile_id = g.thread_rank() / tile_size;
  const unsigned int num_tiles = (g.size() + tile_size - 1) / tile_size;
  const unsigned int lane_id = g.thread_rank() - tile_id * tile_size;

  unsigned int current_index = 0;
  matrixEntriesT current_max = 0.0; 

  /* Reduction in tiles: Each tile can handle more than 1 tilesize of data or no data. */
  for (unsigned int i = tile_id; i * tile_size < ny - row; i += num_tiles)
  {
    unsigned int index = row + tile_id * tile_size + lane_id;
    matrixEntriesT value = (index < ny) ? abs(matrix[index * ld + row]) : 0.0;

    if (value > current_max || ((current_max - value) < 1e-10  && index < current_index))
    { current_max = value; current_index = index; }

    for (unsigned int mask = tile_size / 2; mask > 0; mask /= 2) 
    {
      matrixEntriesT shuffled_max = tile.shfl_xor(current_max, mask);
      unsigned int shuffled_index = tile.shfl_xor(current_index, mask);
      if (shuffled_max > current_max || ((current_max - shuffled_max) < 1e-10  && shuffled_index < current_index)) 
      { current_max = shuffled_max; current_index = shuffled_index; }
    }
  }

  __shared__ matrixEntriesT shm_max[tile_size];
  __shared__ unsigned int shm_index[tile_size];
  if (tile_id == 0) { shm_max[lane_id] = 0.0; shm_index[lane_id] = 0; }
  const unsigned int n = (num_tiles + tile_size - 1) / tile_size;
  const unsigned int slot = tile_id / n;
  const unsigned int turn = tile_id - slot * n;

  g.sync();

  /* Crumbles all tiles into a single tile. */
  for (unsigned int i = 0; i < n; i ++) 
  {
    if (lane_id == 0 && i == turn) 
    {
      if (current_max > shm_max[slot] || ((shm_max[slot] - current_max) < 1e-10  &&  current_index < shm_index[slot]))
      { shm_max[slot] = current_max; shm_index[slot] = current_index; }
    }
    g.sync();
  }

  if (tile_id == 0) /* the final reduction. */
  {
    current_max = shm_max[lane_id];
    current_index = shm_index[lane_id];
    for (unsigned int mask = tile_size / 2; mask > 0; mask /= 2) 
    {
      matrixEntriesT shuffled_max = tile.shfl_xor(current_max, mask);
      unsigned int shuffled_index = tile.shfl_xor(current_index, mask);
      if (shuffled_max > current_max || ((current_max - shuffled_max) < 1e-10  && shuffled_index < current_index)) 
      { current_max = shuffled_max; current_index = shuffled_index; }
    }
    shm_max[lane_id] = current_max;
    shm_index[lane_id] = current_index;
  }

  g.sync();
  const unsigned int warp_id = g.thread_rank() / warpSize;
  const unsigned int warp_slot = warp_id - (warp_id / tile_size) * tile_size; /* warps are mapped to different slots to maximize reading bandwidth. */
  current_max = shm_max[warp_slot];
  current_index = shm_index[warp_slot];

  return current_index;
}

template <class matrixEntriesT>
__device__ void blockExchangeRow (const unsigned int row, const unsigned int target, matrixEntriesT *matrix, const unsigned int nx, const unsigned int ld, const unsigned int ny)
{
  /* Using a block of threads to exchange all elements in row with target row. */
  if (row < ny && target < ny)
  {
    thread_block g = this_thread_block();
    for (unsigned int i = g.thread_rank(); i < nx; i += g.size())
    {
      matrixEntriesT t = matrix[row * ld + i];
      matrix[row * ld + i] = matrix[target * ld + i];
      matrix[target * ld + i] = t;
    }
  }
}

__global__ void partial_pivot_kernel2 (double *matrix, const unsigned nx, const unsigned ld, const unsigned ny, unsigned *p)
{
  blockAllFindRowPivot <double, 32> (4, matrix, nx, ld, ny);
}


#endif