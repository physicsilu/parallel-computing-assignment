/*
 * To solve this question, the basic flow is given as follows:
 * 1. Reading the JSON file and Map product IDs (asin) to integers
 * 2. Then, product_ids[] and ratings[] are created. Both these arrays are populated in CPU itself. No GPU involvement here!
 * 3. We will create a CUDA kernel with Input: product_ids[], ratings[], num_reviews and Output: total_rating_per_product[], count_per_product[]
 * 4. For each review, AtomicAdd to product's total rating and product's count
 * 5. After kernel: Average is computed, sorting happens and pick top 10
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#define MAX_REVIEWS 6800000
#define MAX_STR_LEN 15
#define HASH_TABLE_SIZE 100003
#define MAX_LINE_LENGTH 4096
#define MAX_PRODUCTS HASH_TABLE_SIZE

/*
 * In the code below, we are implementing a Set in C
 * This set stores the unique products along with their unique integer IDs which I give!
 */
typedef struct StringNode
{
    char str[MAX_STR_LEN];
    int id;
    struct StringNode *next;
} StringNode;

StringNode *hash_table[HASH_TABLE_SIZE];
int next_id = 0;

unsigned int hash_string(const char *str)
{
    unsigned int hash = 5381;

    while (*str)
    {
        hash = ((hash << 5) + hash) + *str++;
    }
    return hash % HASH_TABLE_SIZE;
}

int insert_string(const char *str)
{
    unsigned int index = hash_string(str);
    StringNode *curr = hash_table[index];

    while (curr)
    {
        if (strcmp(curr->str, str) == 0)
        {
            return curr->id; // already exists
        }

        curr = curr->next;
    }

    StringNode *new_node = (StringNode *)malloc(sizeof(StringNode));
    strcpy(new_node->str, str);
    new_node->id = next_id++;
    new_node->next = hash_table[index];
    hash_table[index] = new_node;

    return new_node->id;
}

void free_string_set()
{
    for (int i = 0; i < HASH_TABLE_SIZE; i++)
    {
        StringNode *curr = hash_table[i];
        while (curr)
        {
            StringNode *temp = curr;
            curr = curr->next;
            free(temp);
        }
    }
}

/*
 * The code below is for the kernel.
 */

__device__ float d_rating_sums[MAX_PRODUCTS];
__device__ int d_rating_counts[MAX_PRODUCTS];

__global__ void handle_reviews(int *d_product_ids, float *d_ratings)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < MAX_REVIEWS)
    {
        int product = d_product_ids[idx];
        float rating = d_ratings[idx];

        atomicAdd(&d_rating_sums[product], rating);
        atomicAdd(&d_rating_counts[product], 1);
    }
}

typedef struct
{
    int id;
    float avg_rating;
} ProductRating;

int compare(const void *a, const void *b)
{
    float diff = ((ProductRating *)b)->avg_rating - ((ProductRating *)a)->avg_rating;
    if (diff > 0)
        return 1;
    else if (diff < 0)
        return -1;
    else
        return 0;
}

int main()
{
    FILE *fp = fopen("Electronics_5.json", "r");
    int *product_ids = (int *)malloc(MAX_REVIEWS * sizeof(int));
    float *ratings = (float *)malloc(MAX_REVIEWS * sizeof(float));

    char line[MAX_LINE_LENGTH];
    long int line_num = 0;

    while (fgets(line, sizeof(line), fp))
    {
        char *token = strtok(line, ",");
        float rating = -1;
        char asin[MAX_STR_LEN] = "";

        while (token != NULL)
        {
            if (strstr(token, "\"overall\""))
            {
                char *colon = strchr(token, ':');
                if (colon)
                {
                    rating = atof(colon + 1);
                }
            }
            else if (strstr(token, "\"asin\""))
            {
                char *colon = strchr(token, ':');
                if (colon)
                {
                    char *value = colon + 1;
                    while (*value == ' ' || *value == '"')
                    {
                        value++;
                    }
                    char *end = value;
                    while (*end && *end != '"')
                    {
                        end++;
                    }
                    *end = '\0';
                    strcpy(asin, value);
                }
            }

            token = strtok(NULL, ",");
        }

        if (rating >= 0 && asin[0] != '\0')
        {
            int id = insert_string(asin);
            product_ids[line_num] = id;
            ratings[line_num] = rating;
            line_num++;
        }
    }

    char **id_to_asin = (char **)malloc(next_id * sizeof(char *));

    for (int i = 0; i < HASH_TABLE_SIZE; i++)
    {
        StringNode *curr = hash_table[i];
        while (curr)
        {
            id_to_asin[curr->id] = strdup(curr->str); // copy the asin string
            curr = curr->next;
        }
    }

    int *d_product_ids;
    float *d_ratings;

    cudaMalloc(&d_product_ids, MAX_REVIEWS * sizeof(int));
    cudaMalloc(&d_ratings, MAX_REVIEWS * sizeof(float));

    cudaMemcpy(d_product_ids, product_ids, MAX_REVIEWS * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_ratings, ratings, MAX_REVIEWS * sizeof(float), cudaMemcpyHostToDevice);

    int threadsPerBlock = 512;
    int blocks = (MAX_REVIEWS + threadsPerBlock - 1) / threadsPerBlock;

    handle_reviews<<<blocks, threadsPerBlock>>>(d_product_ids, d_ratings);
    cudaDeviceSynchronize();

    float h_rating_sums[MAX_PRODUCTS];
    int h_rating_counts[MAX_PRODUCTS];

    cudaMemcpyFromSymbol(h_rating_sums, d_rating_sums, sizeof(h_rating_sums));
    cudaMemcpyFromSymbol(h_rating_counts, d_rating_counts, sizeof(h_rating_counts));

    for (long i = 0; i < MAX_PRODUCTS; i++)
    {
        if (h_rating_counts[i] > 0)
        {
            h_rating_sums[i] /= h_rating_counts[i];
        }
        else
        {
            h_rating_sums[i] = 0.0f; // or some sentinel value
        }
    }

    ProductRating *products = (ProductRating *)malloc(MAX_PRODUCTS * sizeof(ProductRating));
    int valid_products = 0;

    for (int i = 0; i < MAX_PRODUCTS; i++)
    {
        if (h_rating_counts[i] > 0)
        {
            products[valid_products].id = i;
            products[valid_products].avg_rating = h_rating_sums[i];
            valid_products++;
        }
    }

    qsort(products, valid_products, sizeof(ProductRating), compare);

    printf("\nTop 10 Products by Average Rating:\n");
    for (int i = 0; i < 10 && i < valid_products; i++)
    {
        int id = products[i].id;
        printf("ASIN: %s, Avg Rating: %.2f\n", id_to_asin[id], products[i].avg_rating);
    }

    return 0;
}