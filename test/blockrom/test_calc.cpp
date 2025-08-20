#include <cstdio>
#include <cstdint>

int main() {
    uint64_t j = 0xF4B1CA8127865242ULL;
    
    for (int i = 0; i <= 7; i++) {
        uint64_t mem_value = j * 0x2545F4914F6CDD1DULL;
        uint8_t mem_byte = mem_value & 0xFF;
        
        printf("memory[%d] = 0x%02x (j=0x%016llx, full=0x%016llx)\n", 
               i, mem_byte, (unsigned long long)j, (unsigned long long)mem_value);
        
        j = j ^ (j >> 12);
        j = j ^ (j << 25);
        j = j ^ (j >> 27);
    }
    
    return 0;
}