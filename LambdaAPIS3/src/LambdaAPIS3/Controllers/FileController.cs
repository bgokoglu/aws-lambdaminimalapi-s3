using Amazon.S3;
using Amazon.S3.Model;
using LambdaAPIS3.Models;
using Microsoft.AspNetCore.Mvc;

namespace LambdaAPIS3.Controllers;

[Route("api/files")]
[ApiController]
public class FileController : ControllerBase
{
    private readonly IAmazonS3 _s3Client;
    private readonly ILogger<FileController> _logger;

    public FileController(IAmazonS3 s3Client, ILogger<FileController> logger)
    {
        _s3Client = s3Client;
        _logger = logger;
    }
    
    [HttpPost("upload")]
    public async Task<IActionResult> UploadFileAsync(IFormFile file, string bucketName, string? prefix)
    {
        _logger.LogInformation("===> Checking if bucket exists");
        
        var bucketExists = await Amazon.S3.Util.AmazonS3Util.DoesS3BucketExistV2Async(_s3Client, bucketName);
        
        _logger.LogInformation("===> bucket exists: {BucketExists}", bucketExists);
        
        if (!bucketExists) 
            return NotFound($"Bucket {bucketName} does not exist.");
        
        var request = new PutObjectRequest
        {
            BucketName = bucketName,
            Key = string.IsNullOrEmpty(prefix) ? file.FileName : $"{prefix?.TrimEnd('/')}/{file.FileName}",
            InputStream = file.OpenReadStream()
        };
        request.Metadata.Add("Content-Type", file.ContentType);
        
        _logger.LogInformation("===> Obj created");
        
        await _s3Client.PutObjectAsync(request);
        
        _logger.LogInformation("===> Obj uploaded");
        
        return Ok($"File {prefix}/{file.FileName} uploaded to S3 successfully!");
    }
    
    [HttpGet("get-all")]
    public async Task<IActionResult> GetAllFilesAsync(string bucketName, string? prefix)
    {
        var bucketExists = await Amazon.S3.Util.AmazonS3Util.DoesS3BucketExistV2Async(_s3Client, bucketName);
        if (!bucketExists) 
            return NotFound($"Bucket {bucketName} does not exist.");
        
        var request = new ListObjectsV2Request
        {
            BucketName = bucketName,
            Prefix = prefix
        };
        
        var result = await _s3Client.ListObjectsV2Async(request);
        
        var s3Objects = result.S3Objects.Select(s =>
        {
            var urlRequest = new GetPreSignedUrlRequest()
            {
                BucketName = bucketName,
                Key = s.Key,
                Expires = DateTime.UtcNow.AddMinutes(1)
            };
            return new S3ObjectDto
            {
                Name = s.Key.ToString(),
                PresignedUrl = _s3Client.GetPreSignedURL(urlRequest),
            };
        });
        
        return Ok(s3Objects);
    }
    
    [HttpGet("download")]
    public async Task<IActionResult> GetFileByKeyAsync(string bucketName, string key)
    {
        var bucketExists = await Amazon.S3.Util.AmazonS3Util.DoesS3BucketExistV2Async(_s3Client, bucketName);
        if (!bucketExists) 
            return NotFound($"Bucket {bucketName} does not exist.");
        
        var s3Object = await _s3Client.GetObjectAsync(bucketName, key);
        
        return File(s3Object.ResponseStream, s3Object.Headers.ContentType);
    }
    
    [HttpDelete("delete")]
    public async Task<IActionResult> DeleteFileAsync(string bucketName, string key)
    {
        var bucketExists = await Amazon.S3.Util.AmazonS3Util.DoesS3BucketExistV2Async(_s3Client, bucketName);
        if (!bucketExists) 
            return NotFound($"Bucket {bucketName} does not exist.");
        
        await _s3Client.DeleteObjectAsync(bucketName, key);
        
        return NoContent();
    }
}