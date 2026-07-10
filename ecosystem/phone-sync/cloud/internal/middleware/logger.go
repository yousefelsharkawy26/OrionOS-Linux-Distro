package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
)

func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		c.Next()

		end := time.Now()
		status := c.Writer.Status()
		latency := end.Sub(start)

		gin.DefaultWriter.Write([]byte(
			time.Now().Format("2006-01-02 15:04:05") + " | " +
			c.ClientIP() + " | " +
			method + " " + path + " | " +
			time.Duration(latency).String() + " | " +
			string(rune(status)) + "\n",
		))
	}
}
