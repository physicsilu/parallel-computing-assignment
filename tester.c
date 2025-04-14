/*
 * To solve this question, the basic flow is given as follows: 
 * 1. Reading the JSON file and Map product IDs (asin) to integers
 * 2. Then, product_ids[] and ratings[] are created. Both these arrays are populated in CPU itself. No GPU involvement here!
 */
#include<stdio.h>
#include<string.h>
#include<stdlib.h>
#define MAX_REVIEWS 7000000
#define MAX_STR_LEN 15
#define HASH_TABLE_SIZE 100003
#define MAX_LINE_LENGTH 10000

/*
 * In the code below, we are implementing a Set in C
 * This set stores the unique products along with their unique integer IDs which I give!
 */
typedef struct StringNode
{
    char str[MAX_STR_LEN];
    int id;
    struct StringNode* next;
}StringNode;

StringNode* hash_table[HASH_TABLE_SIZE];
int next_id = 0;

unsigned int hash_string(const char* str){
    unsigned int hash = 5381;

    while (*str)
    {
        hash = ((hash<<5) + hash) + *str++;
    }
    return hash % HASH_TABLE_SIZE;
}

int insert_string(const char* str){
    unsigned int index = hash_string(str);
    StringNode* curr = hash_table[index];

    while (curr)
    {
        if (strcmp(curr->str, str) == 0)
        {
            return curr->id; // already exists
        }
        
        curr = curr->next;
    }

    StringNode* new_node = (StringNode *)malloc(sizeof(StringNode));
    strcpy(new_node->str, str);
    new_node->id = next_id++;
    new_node->next = hash_table[index];
    hash_table[index] = new_node;
    
    return new_node->id;
}

void free_string_set() {
    for (int i = 0; i < HASH_TABLE_SIZE; i++) {
        StringNode *curr = hash_table[i];
        while (curr) {
            StringNode *temp = curr;
            curr = curr->next;
            free(temp);
        }
    }
}
int main(){
    FILE* fp = fopen("test.txt", "r");
    int *product_ids = malloc(MAX_REVIEWS*sizeof(int));
    float *ratings = malloc(MAX_REVIEWS*sizeof(float));

    char line[MAX_LINE_LENGTH];
    int line_num = 0;

    while (fgets(line, sizeof(line), fp))
    {
        char* token = strtok(line, ",");
        float rating = -1;
        char asin[MAX_STR_LEN] = "";

        while (token != NULL)
        {
            if(strstr(token, "\"overall\"")){
                char* colon = strchr(token, ':');
                if (colon)
                {
                    rating = atof(colon+1);
                }
            }
            else if(strstr(token, "\"asin\"")){
                char* colon = strchr(token, ':');
                if (colon)
                {
                    char* value = colon+1;
                    while (*value == ' '|| *value == '"')
                    {
                        value++;
                    }
                    char* end = value;
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
    
    for (int i = 0; i < 10; i++)
    {
        printf("Rating: %f, ID: %d\n", ratings[i], product_ids[i]);
    }
    
    free(product_ids);
    free(ratings);

    return 0;
}