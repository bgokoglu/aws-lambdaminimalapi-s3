using Amazon.Lambda.Core;
using Amazon.Lambda.S3Events;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Util;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;

// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace LambdaImageConverterS3;

public class Function
{
    private readonly IAmazonS3 _s3Client;

    /// <summary>
    /// Default constructor. This constructor is used by Lambda to construct the instance. When invoked in a Lambda environment
    /// the AWS credentials will come from the IAM role associated with the function and the AWS region will be set to the
    /// region the Lambda function is executed in.
    /// </summary>
    public Function()
    {
        _s3Client = new AmazonS3Client();
    }

    /// <summary>
    /// Constructs an instance with a preconfigured S3 client. This can be used for testing outside of the Lambda environment.
    /// </summary>
    /// <param name="s3Client"></param>
    public Function(IAmazonS3 s3Client)
    {
        _s3Client = s3Client;
    }

    /// <summary>
    /// This method is called for every Lambda invocation. This method takes in an S3 event object and can be used 
    /// to respond to S3 notifications.
    /// </summary>
    /// <param name="evnt"></param>
    /// <param name="context"></param>
    /// <returns></returns>
    public async Task FunctionHandler(S3Event evnt, ILambdaContext context)
    {
        var eventRecords = evnt.Records ?? new List<S3Event.S3EventNotificationRecord>();
        
        const string thumbnailFolder = "thumbnails/";
        
        foreach (var s3Event in eventRecords.Select(record => record.S3).Where(s3Event => s3Event != null))
        {
            try
            {
                var bucketName = s3Event.Bucket.Name;
                var key = s3Event.Object.Key;
                
                var metadataResponse = await _s3Client.GetObjectMetadataAsync(s3Event.Bucket.Name, s3Event.Object.Key);
                context.Logger.LogInformation(metadataResponse.Headers.ContentType);
             
                var response = await _s3Client.GetObjectAsync(bucketName, key);
                context.Logger.LogLine($"Original Size of {key}: {response.ContentLength}");

                using var image = await Image.LoadAsync(response.ResponseStream);
                
                const int maxWidth = 50;
                const int maxHeight = 50;
                image.Mutate(x => x.Resize(new ResizeOptions
                {
                    Mode = ResizeMode.Max,
                    Size = new Size(maxWidth, maxHeight)
                }));

                using var stream = new MemoryStream();
                await image.SaveAsync(stream, new SixLabors.ImageSharp.Formats.Jpeg.JpegEncoder());
                
                context.Logger.LogLine($"Thumbnail Size of {key}: {stream.Length}");
                    
                var thumbnailKey = thumbnailFolder + key.Replace("images/", "");
                var uploadRequest = new PutObjectRequest
                {
                    BucketName = bucketName,
                    Key = thumbnailKey,
                    InputStream = stream
                };
                await _s3Client.PutObjectAsync(uploadRequest);
                context.Logger.LogLine($"Uploaded Thumbnail to {thumbnailKey}");

                //delete original image
                // await _s3Client.DeleteObjectAsync(bucketName, s3Event.Object.Key);
                // context.Logger.LogLine($"Deleted Original Image from {s3Event.Object.Key}");
            }
            catch (Exception e)
            {
                context.Logger.LogError($"Error getting object {s3Event.Object.Key} from bucket {s3Event.Bucket.Name}. Make sure they exist and your bucket is in the same region as this function.");
                context.Logger.LogError(e.Message);
                context.Logger.LogError(e.StackTrace);
                throw;
            }
        }
    }
}