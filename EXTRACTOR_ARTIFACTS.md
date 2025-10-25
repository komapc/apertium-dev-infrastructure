# Extractor Artifacts

## Overview

The Ido-Esperanto extractor creates multiple artifacts during its pipeline execution. This document lists all output files and their purposes.

## Main Artifacts (dist/)

### Apertium Dictionaries
- **`apertium-ido.ido.dix`** - Ido monolingual morphological dictionary
- **`apertium-ido-epo.ido-epo.dix`** - Ido↔Esperanto bilingual dictionary

### JSON Dictionaries
- **`ido_dictionary.json`** - Ido monolingual dictionary (JSON format)
- **`esperanto_dictionary.json`** - Esperanto monolingual dictionary (JSON format)
- **`bidix_big.json`** - Main bilingual dictionary (JSON format)
- **`vortaro_dictionary.json`** - Dictionary for vortaro viewer

## Intermediate Artifacts (work/)

### Source Parsing Results
- **`io_wiktionary_processed.json`** - Processed Ido Wiktionary entries
- **`io_wiktionary_filtered.json`** - Filtered Ido Wiktionary entries
- **`io_wikipedia_processed.json`** - Processed Ido Wikipedia entries
- **`io_wikipedia_filtered.json`** - Filtered Ido Wikipedia entries
- **`io_wiki_frequency.json`** - Ido word frequency data

- **`eo_wiktionary_processed.json`** - Processed Esperanto Wiktionary entries
- **`eo_wiktionary_filtered.json`** - Filtered Esperanto Wiktionary entries
- **`eo_all_raw.json`** - Raw Esperanto data
- **`eo_debug.json`** - Debug Esperanto data

### English Wiktionary (Via Language)
- **`en_wikt_en_io.json`** - English→Ido translations
- **`en_wikt_en_eo.json`** - English→Esperanto translations
- **`en_wikt_en_both.json`** - English→Both languages
- **`bilingual_via_en.json`** - Ido↔Esperanto via English

### French Wiktionary (Via Language)
- **`fr_wikt_fr_xx.json`** - French Wiktionary entries
- **`fr_wikt_meanings.json`** - French Wiktionary meanings
- **`fr_wikt_via.json`** - Ido↔Esperanto via French

### Bilingual Processing
- **`io_wikt_io_eo.json`** - Ido→Esperanto from Ido Wiktionary
- **`eo_wikt_eo_io.json`** - Esperanto→Ido from Esperanto Wiktionary
- **`bilingual_raw.json`** - Raw bilingual data
- **`bilingual_normalized.json`** - Normalized bilingual data
- **`bilingual_with_morph.json`** - Bilingual data with morphology

### Final Processing
- **`final_vocabulary.json`** - Final vocabulary compilation

## Artifact Sizes (Typical)

| File | Size | Entries | Description |
|------|------|---------|-------------|
| `apertium-ido.ido.dix` | ~2MB | ~15K | Ido monolingual |
| `apertium-ido-epo.ido-epo.dix` | ~1.5MB | ~8K | Bilingual |
| `ido_dictionary.json` | ~7MB | ~15K | Ido JSON |
| `bidix_big.json` | ~6MB | ~8K | Bilingual JSON |
| `io_wiktionary_processed.json` | ~3MB | ~5K | Ido Wiktionary |
| `eo_wiktionary_processed.json` | ~8MB | ~12K | Esperanto Wiktionary |

## Deployment Artifacts

### Primary (Deployed to Repos)
- `apertium-ido.ido.dix` → `apertium/apertium-ido`
- `apertium-ido-epo.ido-epo.dix` → `apertium/apertium-ido-epo`

### Secondary (Available for Analysis)
- All JSON files for debugging and analysis
- Work files for pipeline debugging
- Log files for troubleshooting

## Source Contributions

### Ido Sources
- **Ido Wiktionary** - Primary Ido vocabulary
- **Ido Wikipedia** - Ido usage examples
- **English Wiktionary** - Ido translations via English
- **French Wiktionary** - Ido translations via French

### Esperanto Sources
- **Esperanto Wiktionary** - Primary Esperanto vocabulary
- **English Wiktionary** - Esperanto translations via English
- **French Wiktionary** - Esperanto translations via French

## Quality Metrics

### Coverage
- **Ido coverage**: ~15,000 entries
- **Esperanto coverage**: ~12,000 entries
- **Bilingual pairs**: ~8,000 entries

### Sources
- **Direct translations**: Ido↔Esperanto Wiktionary
- **Via English**: ~40% of bilingual pairs
- **Via French**: ~10% of bilingual pairs
- **Wikipedia**: Usage examples and frequency

## File Formats

### .dix (Apertium)
```xml
<dictionary>
  <alphabet>abcdefghijklmnopqrstuvwxyz</alphabet>
  <sdefs>
    <sdef n="n"/>
    <sdef n="sg"/>
    <!-- ... -->
  </sdefs>
  <pardefs>
    <!-- Morphological paradigms -->
  </pardefs>
  <section id="main" type="standard">
    <e><p><l>hundo</l><r>hundo<s n="n"/><s n="sg"/><s n="nom"/></r></p></e>
    <!-- ... -->
  </section>
</dictionary>
```

### JSON
```json
{
  "metadata": {
    "source": "io_wiktionary",
    "dump_file": "iowiktionary-latest-pages-articles.xml.bz2",
    "entries": 15000
  },
  "entries": [
    {
      "word": "hundo",
      "pos": "n",
      "translations": ["hundo"],
      "definitions": ["domestic dog"]
    }
  ]
}
```

## Usage

### For Apertium
- Use `.dix` files directly in Apertium translation pairs
- Deploy to `apertium/apertium-ido` and `apertium/apertium-ido-epo`

### For Analysis
- Use JSON files for vocabulary analysis
- Work files for debugging pipeline issues
- Frequency data for word importance

### For Development
- Modify source parsing scripts to improve coverage
- Adjust filtering rules in work files
- Update export scripts for new formats
