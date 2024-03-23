
#define TIFF_ImageWidth      0x0100
#define TIFF_ImageLength     0x0101
#define TIFF_BitsPerSample   0x0102
#define TIFF_Compression     0x0103
#define TIFF_StripOffsets    0x0111
#define TIFF_SamplesPerPixel 0x0115
#define TIFF_RowsPerStrip    0x0116
#define TIFF_StripByteCounts 0x0117
#define TIFF_XResolution     0x011A
#define TIFF_YResolution     0x011B
#define TIFF_ResolutionUnit  0x0128


int load_cell(char* path, f32 *img) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        perror("Error opening file");
        return 1;
    }

    u8 header[4];
    fread(header, 1, 4, file);
    if (header[0] != 'I' || header[1] != 'I' || header[2] != 0x2A || header[3] != 0x00) {
        printf("Not a valid TIFF file or not in little-endian format.\n");
        fclose(file);
        return 1;
    }

    u32 ifd_offset;
    fread(&ifd_offset, sizeof(ifd_offset), 1, file);

    // NOTE: The structure of cell tiffs is very regular. DATA0, IFD0, DATA1, IFD1, ...
    // We could leverage that to read without parsing, seeking less, may be faster.
    u32 iz = 0;
    u32 data_offset = 0;
    u16 data[500*500];
    while (ifd_offset != 0 && iz != 500) {
        // Parse the IFD to find the data offset.
        fseek(file, ifd_offset, SEEK_SET);
        u16 ifd_num_entries;
        fread(&ifd_num_entries, sizeof(ifd_num_entries), 1, file);
        for (int i = 0; i < ifd_num_entries; i++) {
            u16 tag, type;
            u32 count, value;
            fread(&tag, sizeof(tag), 1, file);
            fread(&type, sizeof(type), 1, file);
            fread(&count, sizeof(count), 1, file);
            fread(&value, sizeof(value), 1, file);
            if (tag == TIFF_StripOffsets) {
                data_offset = value;
            } else if (tag == TIFF_StripByteCounts) {
                assert(value == sizeof(u16)*500*500);
            }
        }
        fread(&ifd_offset, sizeof(ifd_offset), 1, file);

        // Read the data.
        fseek(file, data_offset, SEEK_SET);
        fread(&data, sizeof(u16)*500*500, 1, file);
        for (int i = 0; i < 500*500; i++) {
            img[iz*500*500 + i] = (f32)(((f32)data[i])/65535.0f);
        }
        iz++;
    }

    fclose(file);
    return 0;
}
