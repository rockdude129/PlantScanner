# Pl@ntNet API Setup Guide

## About Pl@ntNet API

The app now uses the [Pl@ntNet API](https://my.plantnet.org/) for plant identification. Pl@ntNet is a well-established plant identification service with:

- **70,551 plant species** in their database
- **56 languages** for plant names
- **Time-tested technology** with ~6 identification model updates per year
- **1,270M+ plant identifications** processed
- **Established since 2013** as the first plant ID app

## Getting Your Pl@ntNet API Key

1. Visit [Pl@ntNet API](https://my.plantnet.org/)
2. Click "Sign up" to create an account
3. Navigate to your API key settings page (`/settings/api-key`)
4. Generate your private API key
5. Add it to your `.env` file

## Environment File Setup

Create a `.env` file in the `plant_identifier` directory with the following content:

```
PLANTNET_API_KEY=your_plantnet_api_key_here
GEMINI_API_KEY=your_gemini_api_key_here
```

## API Implementation Details

Based on the [official Pl@ntNet documentation](https://my.plantnet.org/doc/getting-started/introduction):

- **Endpoint**: `https://my-api.plantnet.org/v2/identify/all?api-key=YOUR-API-KEY`
- **Method**: POST with multipart form data
- **API Key**: Passed as query parameter (not in request body)
- **Images**: Uploaded as files using `MultipartFile.fromPath`
- **Organs**: Set to 'auto' for automatic plant organ detection
- **Project**: Uses 'all' to search across all available floras

## How Pl@ntNet API Works

- **Image Upload**: Users can take photos or select images from gallery
- **Auto-Detection**: Pl@ntNet automatically detects plant organs (leaves, flowers, fruits, etc.)
- **High Accuracy**: Uses advanced deep learning technologies with regular updates
- **Multiple Languages**: Supports plant names in 56 different languages
- **Confidence Scoring**: Provides confidence scores for each identification

## API Response Format

The API returns results in this format:
```json
{
  "results": [
    {
      "score": 0.9952006530761719,
      "species": {
        "scientificNameWithoutAuthor": "Hibiscus rosa-sinensis",
        "commonNames": ["Chinese hibiscus", "Hawaiian hibiscus"],
        "family": {"scientificNameWithoutAuthor": "Malvaceae"}
      }
    }
  ]
}
```

## Benefits of Pl@ntNet

- **Proven Technology**: Established since 2013 with millions of identifications
- **Regular Updates**: ~6 model updates per year for improved accuracy
- **Large Database**: Over 70,000 plant species
- **Multi-language Support**: Plant names in 56 languages
- **Reliable Service**: Used by 1800+ active accounts
- **Advanced AI**: Based on most advanced deep learning technologies

## Troubleshooting

If you get "No plant identified" errors:

1. **Check API Key**: Ensure your API key is correct and active
2. **Image Quality**: Make sure images are clear and show plant features well
3. **API Limits**: Check if you've exceeded your API quota
4. **Network**: Ensure stable internet connection

## Note

The app maintains the same user experience - users simply take a photo or select an image, and the app will identify the plant using Pl@ntNet's advanced AI technology. The Gemini AI integration for plant care summaries remains unchanged. 