#include <cstdio>
#include <cstdint>

int main() {
    // j is integer (32-bit signed)
    int32_t j = 0x27865242;  // Lower 32 bits of the constant
    
    for (int i = 0; i <= 7; i++) {
        // Multiplication with 64-bit constant
        uint64_t mem_value = (uint64_t)(uint32_t)j * 0x2545F4914F6CDD1DULL;
        uint8_t mem_byte = mem_value & 0xFF;
        
        printf("memory[%d] = 0x%02x (j=0x%08x)\n", i, mem_byte, j);
        
        // These bit operations on 32-bit integer
        j = j ^ (j >> 12);
        j = j ^ (j << 25);
        j = j ^ (j >> 27);
    }
    
    return 0;
}